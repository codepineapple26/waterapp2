import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:waterapp2/services/pocketbase_service.dart';

class OrderStatusTimeline extends StatefulWidget {
  const OrderStatusTimeline({
    super.key,
    required this.orderId,
  });

  /// PocketBase record ID, kept in code and not displayed.
  final String orderId;

  @override
  State<OrderStatusTimeline> createState() => _OrderStatusTimelineState();
}

class _OrderStatusTimelineState extends State<OrderStatusTimeline> {
  late Future<List<RecordModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  @override
  void didUpdateWidget(covariant OrderStatusTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orderId != widget.orderId) {
      _historyFuture = _loadHistory();
    }
  }

  Future<List<RecordModel>> _loadHistory() {
    final filter = pb.filter(
      'order = {:orderId}',
      {'orderId': widget.orderId},
    );

    return pb.collection('order_status_history').getFullList(
          filter: filter,
          sort: 'created',
        );
  }

  void _refresh() {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  String _formatStatus(String status) {
    final words = status.replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Status updated';

    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return 'Date unavailable';

    return DateFormat('MMM d, y • h:mm a').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Order status history',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh status history',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<RecordModel>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Could not load order status history.'),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  );
                }

                final records = snapshot.data ?? [];

                if (records.isEmpty) {
                  return const Text('No status updates yet.');
                }

                return Column(
                  children: [
                    for (var i = 0; i < records.length; i++)
                      _TimelineEntry(
                        status: _formatStatus(
                          records[i].getStringValue('status'),
                        ),
                        date: _formatDate(
                          records[i].getStringValue('created'),
                        ),
                        isLast: i == records.length - 1,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.status,
    required this.date,
    required this.isLast,
  });

  final String status;
  final String date;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Icon(Icons.circle, size: 12, color: color),
              if (!isLast)
                Container(
                  width: 2,
                  height: 36,
                  color: color.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
