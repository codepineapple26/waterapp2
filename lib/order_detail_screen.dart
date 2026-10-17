import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:waterapp2/order_status_timeline.dart';
import 'package:waterapp2/services/pocketbase_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final ValueChanged<Map<String, dynamic>>? onReorder;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.onReorder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<RecordModel> _orderFuture;

  RecordModel? _cancellationRequest;
  bool _isLoadingCancellation = true;
  bool _cancellationLoadFailed = false;
  bool _isUpdatingStatus = false;
  bool _isSubmittingCancellation = false;

  String? _selectedStatus;
  String? _amountPaidOrderId;
  bool _amountPaidLocked = false;

  final TextEditingController _amountPaidController =
      TextEditingController();

  final List<String> _statuses = [
    'New',
    'Accepted',
    'Out for delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
    _loadCancellationRequest();
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _loadCancellationRequest() async {
    if (mounted) {
      setState(() {
        _isLoadingCancellation = true;
        _cancellationLoadFailed = false;
      });
    }

    try {
      final result = await pb.collection('cancellation_requests').getList(
            page: 1,
            perPage: 1,
            filter: 'order = "${widget.orderId}"',
            sort: '-created',
          );

      if (!mounted) return;

      setState(() {
        _cancellationRequest =
            result.items.isEmpty ? null : result.items.first;
        _isLoadingCancellation = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cancellationLoadFailed = true;
        _isLoadingCancellation = false;
      });
    }
  }

  Future<void> _refreshDetails() async {
    setState(() {
      _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
    });

    await _loadCancellationRequest();
  }

  Future<void> _saveOrderUpdates(
    RecordModel order,
    String newStatus,
  ) async {
    final amountText = _amountPaidController.text.trim();
    final amountPaid = double.tryParse(amountText);

    if (amountPaid == null || amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount paid')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm delivery update'),
        content: Text(
          'Save status as "$newStatus" and amount paid as '
          '${amountPaid.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final body = <String, dynamic>{
        'status': newStatus,
        'amount_paid': amountPaid,
      };

      final existingDeliveryDate = order.data['delivery_date'];

      // The backend hook should also set this when status becomes Delivered.
      if (newStatus.toLowerCase() == 'delivered' &&
          (existingDeliveryDate == null ||
              existingDeliveryDate.toString().isEmpty)) {
        body['delivery_date'] = DateTime.now().toUtc().toIso8601String();
      }

      await PocketBaseService().updateOrderFields(order.id, body);

      if (!mounted) return;

      setState(() {
        _selectedStatus = null;
        _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _requestCancellation(RecordModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request cancellation?'),
        content: const Text(
          'Your cancellation request will be sent to the delivery team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmittingCancellation = true);

    try {
      final request = await pb.collection('cancellation_requests').create(
        body: {
          'order': order.id,
          'reason': '',
          'request_status': 'pending',
        },
      );

      if (!mounted) return;

      setState(() {
        _cancellationRequest = request;
        _cancellationLoadFailed = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation request sent')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCancellation = false);
      }
    }
  }

  void _reorder(RecordModel order) {
    widget.onReorder?.call({
      'customer_name': order.getStringValue('customer_name'),
      'phone': order.getStringValue('phone'),
      'address': order.getStringValue('address'),
      'quantity': order.getIntValue('quantity'),
      'notes': order.data['notes'] ?? '',
    });

    Navigator.of(context).pop();
  }

  Widget _buildRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDynamic(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    return value.toString();
  }

  String _formatCreated(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    return DateFormat('MMM d, y • h:mm a').format(date.toLocal());
  }

  String get _cancellationStatus {
    final status =
        _cancellationRequest?.getStringValue('request_status').trim();

    if (status == null || status.isEmpty) return '—';

    return status[0].toUpperCase() + status.substring(1);
  }

  bool get _canRequestCancellation {
    final status =
        _cancellationRequest?.getStringValue('request_status').toLowerCase();

    return _cancellationRequest == null || status == 'rejected';
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = pb.authStore.model?.data['role'] == 'driver';

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: FutureBuilder<RecordModel>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load order: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Order not found.'));
          }

          final order = snapshot.data!;

          final id = order.id;
          final customerName = order.getStringValue('customer_name');
          final phone = order.getStringValue('phone');
          final address = order.getStringValue('address');
          final quantity = order.getIntValue('quantity').toString();
          final notes = _formatDynamic(order.data['notes']);
          final status = order.getStringValue('status').trim();
          final total = _formatDynamic(order.data['total']);
          final rawAmountPaid = order.data['amount_paid'];
          final amountPaidValue =
              rawAmountPaid is num ? rawAmountPaid.toDouble() : 0.0;
          final amountPaid = _formatDynamic(rawAmountPaid);
          final deliveryDate = _formatCreated(order.data['delivery_date']);
          final driverId = _formatDynamic(order.data['driver_id']);
          final created = _formatCreated(order.getStringValue('created'));
          final updated = _formatDynamic(
            order.data['updated'] ?? order.getStringValue('updated'),
          );

          // Only initialize the controller once per order. A non-zero saved
          // payment locks the field until that value is cleared in PocketBase.
          if (_amountPaidOrderId != id) {
            _amountPaidOrderId = id;
            _amountPaidController.text =
                rawAmountPaid == null ? '0' : amountPaid;
            _amountPaidLocked = amountPaidValue != 0;
            _selectedStatus = null;
          }

          final statusOptions = List<String>.from(_statuses);
          if (status.isNotEmpty && !statusOptions.contains(status)) {
            statusOptions.insert(0, status);
          }

          final selectedStatus = _selectedStatus ?? status;

          final cancellationStatus = _cancellationLoadFailed
              ? 'Could not load status'
              : _isLoadingCancellation
                  ? 'Loading…'
                  : _cancellationStatus;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRow('Customer', customerName),
                _buildRow('Phone', phone),
                _buildRow('Address', address),
                _buildRow('Quantity', quantity),
                _buildRow('Notes', notes),

                if (isDriver) ...[
                  DropdownButtonFormField<String>(
                    value: statusOptions.contains(selectedStatus)
                        ? selectedStatus
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Order status',
                    ),
                    items: statusOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: _isUpdatingStatus
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedStatus = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountPaidController,
                    readOnly: _amountPaidLocked,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount paid',
                      border: const OutlineInputBorder(),
                      helperText: _amountPaidLocked
                          ? 'Locked after a non-zero payment is saved. Clear it in PocketBase to edit.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingStatus
                          ? null
                          : () => _saveOrderUpdates(order, selectedStatus),
                      child: Text(
                        _isUpdatingStatus ? 'Saving…' : 'Save updates',
                      ),
                    ),
                  ),
                ] else
                  _buildRow('Status', status.isEmpty ? '—' : status),

                if (_isUpdatingStatus) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],

                _buildRow('Total', total),
                _buildRow('Amount paid', amountPaid),
                _buildRow('Delivery date', deliveryDate),
                _buildRow('Driver', driverId),
                const SizedBox(height: 12),
                _buildRow('Created', created),
                _buildRow('Updated', updated),
                const SizedBox(height: 20),

                OrderStatusTimeline(orderId: id),
                const SizedBox(height: 20),

                if (widget.onReorder != null &&
                    status.toLowerCase() != 'delivered') ...[
                  _buildRow('Cancellation request', cancellationStatus),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoadingCancellation ||
                              _cancellationLoadFailed ||
                              _isSubmittingCancellation ||
                              !_canRequestCancellation
                          ? (_cancellationLoadFailed
                              ? _loadCancellationRequest
                              : null)
                          : () => _requestCancellation(order),
                      child: Text(
                        _isSubmittingCancellation
                            ? 'Sending request...'
                            : _isLoadingCancellation
                                ? 'Loading request status...'
                                : _cancellationLoadFailed
                                    ? 'Retry loading request status'
                                    : !_canRequestCancellation
                                        ? 'Cancellation $_cancellationStatus'
                                        : 'Request cancellation',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (widget.onReorder != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _reorder(order),
                      icon: const Icon(Icons.replay),
                      label: const Text('Reorder this order'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  onPressed: _refreshDetails,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
