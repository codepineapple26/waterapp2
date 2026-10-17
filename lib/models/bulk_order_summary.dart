class BulkOrderSummary {
  const BulkOrderSummary({
    required this.orderedQuantity,
    required this.deliveredQuantity,
    required this.remainingQuantity,
    required this.totalCharged,
    required this.totalPaid,
    required this.amountDue,
  });

  final int orderedQuantity;
  final int deliveredQuantity;
  final int remainingQuantity;
  final double totalCharged;
  final double totalPaid;
  final double amountDue;
}
