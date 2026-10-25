import 'package:flutter/material.dart';
import '../../data/listening_calendar.dart';

class ListeningDatesDialog extends StatefulWidget {
  const ListeningDatesDialog({super.key, required this.now, this.initial});
  final DateTime now;
  final DateTimeRange? initial;
  @override
  State<ListeningDatesDialog> createState() => _ListeningDatesDialogState();
}

class _ListeningDatesDialogState extends State<ListeningDatesDialog> {
  final form = GlobalKey<FormState>();
  DateTime? start;
  DateTime? end;
  String? error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Custom dates'),
    content: SizedBox(
      width: double.maxFinite,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputDatePickerFormField(
              firstDate: DateTime(1970),
              lastDate: ListeningCalendar.day(widget.now),
              initialDate:
                  widget.initial?.start ?? ListeningCalendar.day(widget.now),
              fieldLabelText: MaterialLocalizations.of(
                context,
              ).dateRangeStartLabel,
              onDateSaved: (value) => start = value,
            ),
            const SizedBox(height: 16),
            InputDatePickerFormField(
              firstDate: DateTime(1970),
              lastDate: ListeningCalendar.day(widget.now),
              initialDate:
                  widget.initial?.end ?? ListeningCalendar.day(widget.now),
              fieldLabelText: MaterialLocalizations.of(
                context,
              ).dateRangeEndLabel,
              onDateSaved: (value) => end = value,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          form.currentState!.save();
          if (end!.isBefore(start!)) {
            setState(() => error = 'End date must not precede start date.');
            return;
          }
          final value = DateTimeRange(start: start!, end: end!);
          if (!ListeningCalendar.validCustom(value, widget.now)) {
            setState(
              () => error =
                  'Choose at most 366 calendar days, ending no later than today.',
            );
            return;
          }
          Navigator.pop(context, value);
        },
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  );
}
