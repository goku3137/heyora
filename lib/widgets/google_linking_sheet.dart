import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class GoogleLinkingSheet extends StatefulWidget {
  final String title;
  final String description;
  final VoidCallback onLinked;

  const GoogleLinkingSheet({
    super.key,
    required this.title,
    required this.description,
    required this.onLinked,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required VoidCallback onLinked,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GoogleLinkingSheet(
        title: title,
        description: description,
        onLinked: onLinked,
      ),
    );
  }

  @override
  State<GoogleLinkingSheet> createState() => _GoogleLinkingSheetState();
}

class _GoogleLinkingSheetState extends State<GoogleLinkingSheet> {
  bool _isLoading = false;

  Future<void> _handleLinkWithGoogle() async {
    setState(() => _isLoading = true);
    final success = await SupabaseService.instance.linkWithGoogle();
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        widget.onLinked();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Could not link Google account. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.6 : 0.15),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colors.primaryCTA.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: colors.primaryCTA.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Icon(Icons.shield_rounded, color: colors.primaryCTA, size: 30),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Continue with Google Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.isDark ? Colors.white : const Color(0xFFF1F3F7),
                  foregroundColor: Colors.black,
                  elevation: colors.isDark ? 2 : 0,
                  side: colors.isDark ? null : BorderSide(color: colors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _handleLinkWithGoogle,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.g_mobiledata_rounded, size: 32, color: Colors.redAccent),
                label: Text(
                  _isLoading ? 'Linking account...' : 'Continue with Google',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Not Now Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Not now',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
