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
  late Future<List<RecordModel>> _deliveriesFuture;

  RecordModel? _cancellationRequest;
  bool _isLoadingCancellation = true;
  bool _cancellationLoadFailed = false;
  bool _isUpdatingStatus = false;
  bool _isSubmittingCancellation = false;
  bool _isConfirmingDelivery = false;
  bool _isRequestingDelivery = false;

  String? _selectedStatus;
  String? _amountPaidOrderId;
  bool _amountPaidLocked = false;

  final TextEditingController _amountPaidController =
      TextEditingController();

  final List<String> _statuses = [
    'New',
    'Accepted',
    'Out for delivery',
  ];

  @override
  void initState() {
    super.initState();
    _orderFuture = PocketBaseService().fetchOrderById(widget.orderId);
    _deliveriesFuture = _loadOrderDeliveries();
    _loadCancellationRequest();
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  Future<List<RecordModel>> _loadOrderDeliveries() {
    return pb.collection('order_deliveries').getFullList(
          filter: 'order = "${widget.orderId}"',
          sort: 'created',
        );
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
      _deliveriesFuture = _loadOrderDeliveries();
    });

    await _loadCancellationRequest();
  }

  Future<void> _requestDelivery(
    RecordModel order,
    int availableQuantity,
  ) async {
    if (availableQuantity <= 0) return;

    final quantityController = TextEditingController();
    var requestedFor = DateTime.now();
    String? validationError;

    final requestedQuantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request delivery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available to schedule: $availableQuantity bottles'),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  errorText: validationError,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: requestedFor,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(
                      const Duration(days: 365 * 3),
                    ),
                  );

                  if (picked != null) {
                    setDialogState(() => requestedFor = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  'Requested for: ${DateFormat('MMM d, y').format(requestedFor)}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text.trim());

                if (quantity == null ||
                    quantity < 1 ||
                    quantity > availableQuantity) {
                  setDialogState(() {
                    validationError =
                        'Enter a quantity from 1 to $availableQuantity.';
                  });
                  return;
                }

                Navigator.pop(dialogContext, quantity);
              },
              child: const Text('Request'),
            ),
          ],
        ),
      ),
    );

    quantityController.dispose();

    if (requestedQuantity == null || !mounted) return;

    setState(() => _isRequestingDelivery = true);

    try {
      await pb.collection('order_deliveries').create(
        body: {
          'order': order.id,
          'quantity': requestedQuantity,
          'status': 'requested',
          'requested_for': requestedFor.toUtc().toIso8601String(),
        },
      );

      await _refreshDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery requested')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request delivery: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRequestingDelivery = false);
      }
    }
  }

  Future<void> _startDelivery(RecordModel delivery) async {
    try {
      await pb.collection('order_deliveries').update(
        delivery.id,
        body: {'status': 'out_for_delivery'},
      );

      await _refreshDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery marked as out for delivery')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update delivery: $e')),
      );
    }
  }

  Future<void> _markDeliveryDelivered(
    RecordModel order,
    RecordModel delivery,
  ) async {
    try {
      await pb.collection('order_deliveries').update(
        delivery.id,
        body: {
          'status': 'delivered',
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final deliveries = await _loadOrderDeliveries();
      final deliveredQuantity = deliveries
          .where((item) => item.data['status'] == 'delivered')
          .fold<int>(
            0,
            (sum, item) => sum + item.getIntValue('quantity'),
          );

      // The parent order becomes Delivered only after all its bottles
      // have been delivered across the individual delivery records.
      if (deliveredQuantity >= order.getIntValue('quantity')) {
        await PocketBaseService().updateOrderFields(
          order.id,
          {
            'status': 'Delivered',
            'delivery_date': DateTime.now().toUtc().toIso8601String(),
          },
        );
      }

      await _refreshDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery marked as delivered')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete delivery: $e')),
      );
    }
  }

  Future<void> _confirmCustomerDelivery(String deliveryId) async {
    setState(() => _isConfirmingDelivery = true);

    try {
      await pb.collection('order_deliveries').update(
        deliveryId,
        body: {
          'customer_confirmation': true,
          'confirmed_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      await _refreshDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery confirmed')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm delivery: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isConfirmingDelivery = false);
      }
    }
  }

  Future<void> _saveOrderUpdates(
    RecordModel order,
    String newStatus,
  ) async {
    if (newStatus.toLowerCase() == 'delivered') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mark individual deliveries as delivered. The order will be '
            'marked delivered when its full quantity has been delivered.',
          ),
        ),
      );
      return;
    }

    final amountText = _amountPaidController.text.trim();
    final amountPaid = double.tryParse(amountText);

    if (amountPaid == null || amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount paid')),
      );
      return;
    }

    if (_amountPaidLocked) {
      final currentAmount = order.data['amount_paid'];
      final savedAmount =
          currentAmount is num ? currentAmount.toDouble() : 0.0;

      if (amountPaid != savedAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Amount paid is locked. Clear it in PocketBase before editing.',
            ),
          ),
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm order update'),
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
      await PocketBaseService().updateOrderFields(
        order.id,
        {
          'status': newStatus,
          'amount_paid': amountPaid,
        },
      );

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

  Widget _buildDeliveryCard(
    RecordModel order,
    RecordModel delivery,
    bool isDriver,
  ) {
    final status = delivery.getStringValue('status');
    final quantity = delivery.getIntValue('quantity');
    final requestedFor = _formatCreated(delivery.data['requested_for']);
    final deliveredAt = _formatCreated(delivery.data['delivered_at']);
    final confirmed = delivery.data['customer_confirmation'] == true;
    final confirmedAt = _formatCreated(delivery.data['confirmed_at']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$quantity bottles • ${status.replaceAll('_', ' ')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            _buildRow('Requested for', requestedFor),
            if (status == 'delivered') ...[
              _buildRow('Delivered at', deliveredAt),
              _buildRow(
                'Customer confirmation',
                confirmed ? 'Confirmed' : 'Not confirmed',
              ),
              if (confirmed) _buildRow('Confirmed at', confirmedAt),
            ],
            if (isDriver && status == 'requested') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startDelivery(delivery),
                  child: const Text('Start delivery'),
                ),
              ),
            ],
            if (isDriver && status == 'out_for_delivery') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _markDeliveryDelivered(order, delivery),
                  child: const Text('Mark delivered'),
                ),
              ),
            ],
            if (!isDriver && status == 'delivered' && !confirmed) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConfirmingDelivery
                      ? null
                      : () => _confirmCustomerDelivery(delivery.id),
                  icon: _isConfirmingDelivery
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isConfirmingDelivery
                        ? 'Confirming…'
                        : 'Confirm this delivery',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
          final totalQuantity = order.getIntValue('quantity');
          final notes = _formatDynamic(order.data['notes']);
          final status = order.getStringValue('status').trim();
          final isDelivered = status.toLowerCase() == 'delivered';
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

          if (_amountPaidOrderId != id) {
            _amountPaidOrderId = id;
            _amountPaidController.text =
                rawAmountPaid == null ? '0' : amountPaid;
            _amountPaidLocked = amountPaidValue != 0;
            _selectedStatus = null;
          }

          final statusOptions = List<String>.from(_statuses);
          if (status.isNotEmpty &&
              !statusOptions.contains(status) &&
              status.toLowerCase() != 'delivered') {
            statusOptions.insert(0, status);
          }

          final selectedStatus = _selectedStatus ?? status;

          final cancellationStatus = _cancellationLoadFailed
              ? 'Could not load status'
              : _isLoadingCancellation
                  ? 'Loading…'
                  : _cancellationStatus;

          return FutureBuilder<List<RecordModel>>(
            future: _deliveriesFuture,
            builder: (context, deliverySnapshot) {
              if (deliverySnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (deliverySnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Failed to load deliveries: ${deliverySnapshot.error}',
                    ),
                  ),
                );
              }

              final deliveries =
                  deliverySnapshot.data ?? <RecordModel>[];

              final deliveredQuantity = deliveries
                  .where((delivery) => delivery.data['status'] == 'delivered')
                  .fold<int>(
                    0,
                    (sum, delivery) =>
                        sum + delivery.getIntValue('quantity'),
                  );

              final allocatedQuantity = deliveries.fold<int>(
                0,
                (sum, delivery) => sum + delivery.getIntValue('quantity'),
              );

              final remainingQuantity =
                  totalQuantity - deliveredQuantity;
              final availableToSchedule =
                  (totalQuantity - allocatedQuantity).clamp(0, totalQuantity);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRow('Customer', customerName),
                    _buildRow('Phone', phone),
                    _buildRow('Address', address),
                    _buildRow('Quantity', '$totalQuantity'),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount paid',
                          border: const OutlineInputBorder(),
                          helperText: _amountPaidLocked
                              ? 'Locked after a non-zero payment is saved. '
                                  'Clear it in PocketBase to edit.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUpdatingStatus
                              ? null
                              : () => _saveOrderUpdates(
                                    order,
                                    selectedStatus,
                                  ),
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
                    _buildRow(
                      'Delivered quantity',
                      '$deliveredQuantity of $totalQuantity bottles',
                    ),
                    _buildRow(
                      'Remaining quantity',
                      '${remainingQuantity < 0 ? 0 : remainingQuantity} bottles',
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'Deliveries',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (deliveries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No deliveries have been requested yet.'),
                      )
                    else
                      ...deliveries.map(
                        (delivery) =>
                            _buildDeliveryCard(order, delivery, isDriver),
                      ),

                    if (!isDriver && availableToSchedule > 0) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isRequestingDelivery
                              ? null
                              : () => _requestDelivery(
                                    order,
                                    availableToSchedule,
                                  ),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: Text(
                            _isRequestingDelivery
                                ? 'Requesting…'
                                : 'Request delivery',
                          ),
                        ),
                      ),
                    ],
                    if (_isRequestingDelivery) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],

                    _buildRow('Driver', driverId),
                    const SizedBox(height: 12),
                    _buildRow('Created', created),
                    _buildRow('Updated', updated),
                    const SizedBox(height: 20),

                    OrderStatusTimeline(orderId: id),
                    const SizedBox(height: 20),

                    if (widget.onReorder != null && !isDelivered) ...[
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
                                            ? 'Cancellation '
                                                '$_cancellationStatus'
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
          );
        },
      ),
    );
  }
}
