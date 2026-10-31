import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ReportDialog extends StatefulWidget {
  final String strangerId;
  final Function(String reason) onReported;

  const ReportDialog({
    super.key,
    required this.strangerId,
    required this.onReported,
  });

  static Future<void> show(
    BuildContext context, {
    required String strangerId,
    required Function(String reason) onReported,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ReportDialog(
        strangerId: strangerId,
        onReported: onReported,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;

  final List<String> _reasons = [
    'Nudity or Sexual Content',
    'Harassment or Hate Speech',
    'Underage Person (< 18)',
    'Violence or Dangerous Act',
    'Commercial Spam / Solicitation',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.2),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Report & Block User',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select reason for reporting. This user will be immediately blocked from matching with you again.',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ..._reasons.map((reason) {
            final isSelected = _selectedReason == reason;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedReason = reason;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : colors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.redAccent : colors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Colors.redAccent : colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _selectedReason == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onReported(_selectedReason!);
                },
          child: const Text('SUBMIT & BLOCK', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
