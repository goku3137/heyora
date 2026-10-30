import 'package:flutter/material.dart';

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
    return AlertDialog(
      backgroundColor: const Color(0xFF161828),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.pinkAccent, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Community Guidelines',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HeyOra is a safe 1-on-1 random video platform for adults (18+).',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _ruleItem(Icons.no_adult_content, 'Zero Tolerance for Nudity',
                'Exposing yourself or showing adult content results in an instant permanent device ban.'),
            _ruleItem(Icons.block, 'No Harassment or Hate Speech',
                'Be respectful to strangers. Bullying or inappropriate behavior will be reported to authorities.'),
            _ruleItem(Icons.flag, 'Instant Report & Block',
                'You can tap the Report button at any second to block a stranger and end the call.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'I certify that I am at least 18 years old and agree to follow the safety rules.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
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
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
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

  Widget _ruleItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.pinkAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
