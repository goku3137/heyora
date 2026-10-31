import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SafetyDialog extends StatelessWidget {
  final VoidCallback onAccepted;

  const SafetyDialog({super.key, required this.onAccepted});

  static Future<bool?> show(BuildContext context, VoidCallback onAccepted) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SafetyDialog(onAccepted: onAccepted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.divider, width: 1.0),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primaryCTA.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: colors.primaryCTA, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Community Guidelines',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HeyOra is a safe 1-on-1 random video platform for adults (18+).',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _ruleItem(
              context,
              Icons.no_adult_content,
              'Zero Tolerance for Nudity',
              'Exposing yourself or showing adult content results in an instant permanent device ban.',
            ),
            _ruleItem(
              context,
              Icons.block,
              'No Harassment or Hate Speech',
              'Be respectful to strangers. Bullying or inappropriate behavior will be reported to authorities.',
            ),
            _ruleItem(
              context,
              Icons.flag,
              'Instant Report & Block',
              'You can tap the Report button at any second to block a stranger and end the call.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: colors.primaryCTA, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'I certify that I am at least 18 years old and agree to follow the safety rules.',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primaryCTA,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
              onAccepted();
            },
            child: const Text(
              'I AGREE & CONTINUE (18+)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ruleItem(BuildContext context, IconData icon, String title, String desc) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primaryCTA, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
