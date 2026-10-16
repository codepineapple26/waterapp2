import 'package:flutter/material.dart';

class DeliverySlot {
  const DeliverySlot({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class DeliverySchedule {
  const DeliverySchedule({
    required this.date,
    required this.slot,
  });

  final DateTime date;
  final DeliverySlot slot;

  Map<String, dynamic> toJson() {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return {
      'requestedDeliveryDate': '$year-$month-$day',
      'deliveryWindowId': slot.id,
      'deliveryWindowLabel': slot.label,
      'deliveryStatus': 'requested',
    };
  }
}

class DeliverySchedulePicker extends StatefulWidget {
  const DeliverySchedulePicker({
    super.key,
    required this.onChanged,
  });

  final ValueChanged<DeliverySchedule> onChanged;

  @override
  State<DeliverySchedulePicker> createState() =>
      _DeliverySchedulePickerState();
}

class _DeliverySchedulePickerState extends State<DeliverySchedulePicker> {
  static const List<DeliverySlot> _slots = [
    DeliverySlot(id: 'morning', label: '9:00 AM – 12:00 PM'),
    DeliverySlot(id: 'afternoon', label: '12:00 PM – 3:00 PM'),
    DeliverySlot(id: 'evening', label: '3:00 PM – 6:00 PM'),
  ];

  late final List<DateTime> _availableDates;
  late DateTime _selectedDate;
  DeliverySlot? _selectedSlot;

  @override
  void initState() {
    super.initState();

    final today = DateUtils.dateOnly(DateTime.now());
    _availableDates = List.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );
    _selectedDate = _availableDates.first;
  }

  void _notifyParent() {
    final slot = _selectedSlot;
    if (slot == null) return;

    widget.onChanged(
      DeliverySchedule(date: _selectedDate, slot: slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<DateTime>(
          value: _selectedDate,
          decoration: const InputDecoration(
            labelText: 'Delivery date',
            border: OutlineInputBorder(),
          ),
          items: _availableDates.map((date) {
            return DropdownMenuItem<DateTime>(
              value: date,
              child: Text(
                MaterialLocalizations.of(context).formatMediumDate(date),
              ),
            );
          }).toList(),
          onChanged: (date) {
            if (date == null) return;
            setState(() => _selectedDate = date);
            _notifyParent();
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose a delivery time',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ..._slots.map(
          (slot) => RadioListTile<DeliverySlot>(
            contentPadding: EdgeInsets.zero,
            title: Text(slot.label),
            value: slot,
            groupValue: _selectedSlot,
            onChanged: (selectedSlot) {
              if (selectedSlot == null) return;
              setState(() => _selectedSlot = selectedSlot);
              _notifyParent();
            },
          ),
        ),
      ],
    );
  }
}
