import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_state.dart';
import '../theme/app_colors.dart';
import '../widgets/google_linking_sheet.dart';

class SettingsScreen extends StatelessWidget {
  final UserState userState;

  const SettingsScreen({super.key, required this.userState});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: userState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(
              'Settings & Safety',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Account Profile Card
                  _buildSectionHeader(colors, 'ACCOUNT & IDENTITY'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: colors.primaryCTA.withValues(alpha: 0.15),
                              child: Icon(
                                userState.isAnonymous ? Icons.person_outline_rounded : Icons.account_circle_rounded,
                                color: colors.primaryCTA,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          userState.isAnonymous ? 'Guest Explorer' : userState.userDisplayName,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: userState.isAnonymous
                                              ? colors.divider
                                              : Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          userState.isAnonymous ? 'GUEST' : 'VERIFIED',
                                          style: TextStyle(
                                            color: userState.isAnonymous ? colors.textSecondary : Colors.green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    userState.isAnonymous
                                        ? 'Temporary device identity'
                                        : userState.userEmail,
                                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: colors.divider),
                        const SizedBox(height: 10),

                        // Action button based on state
                        if (userState.isAnonymous) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primaryCTA,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                GoogleLinkingSheet.show(
                                  context,
                                  title: 'Link Google Account',
                                  description: 'Protect your wallet balance and restore it on any device.',
                                  onLinked: () {},
                                );
                              },
                              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                              label: const Text(
                                'Protect Account with Google',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Linked with Google',
                                style: TextStyle(color: colors.textSecondary, fontSize: 12),
                              ),
                              TextButton(
                                onPressed: () => _confirmLogout(context, colors),
                                child: Text(
                                  'Switch to Guest',
                                  style: TextStyle(color: colors.primaryCTA, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // User ID Snippet
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'User ID: ${userState.currentUserId.substring(0, 12)}...',
                              style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: userState.currentUserId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User ID copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Text(
                                'Copy ID',
                                style: TextStyle(
                                  color: colors.secondaryAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. App Appearance
                  _buildSectionHeader(colors, 'APP APPEARANCE'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme Mode',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Calls always use Cinema Mode to protect face lighting.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.divider),
                          ),
                          child: Row(
                            children: [
                              _buildThemeOption(context, 'System', ThemeMode.system, Icons.brightness_auto, colors),
                              _buildThemeOption(context, 'Dark', ThemeMode.dark, Icons.dark_mode_outlined, colors),
                              _buildThemeOption(context, 'Light', ThemeMode.light, Icons.light_mode_outlined, colors),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Legal, Privacy & Terms
                  _buildSectionHeader(colors, 'LEGAL & COMMUNITY SAFETY'),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context,
                          colors,
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          subtitle: 'Camera P2P encryption, zero recording & data retention',
                          onTap: () => _showPrivacyPolicyDialog(context, colors),
                        ),
                        Divider(color: colors.divider, height: 1),
                        _buildSettingTile(
                          context,
                          colors,
                          icon: Icons.gavel_rounded,
                          title: 'Terms of Service',
                          subtitle: 'User agreement, 18+ eligibility & rules',
                          onTap: () => _showTermsOfServiceDialog(context, colors),
                        ),
                        Divider(color: colors.divider, height: 1),
                        _buildSettingTile(
                          context,
                          colors,
                          icon: Icons.shield_outlined,
                          title: 'Community Guidelines',
                          subtitle: 'Zero tolerance for nudity, bullying & harassment',
                          onTap: () => _showCommunityGuidelinesDialog(context, colors),
                        ),
                        Divider(color: colors.divider, height: 1),
                        _buildSettingTile(
                          context,
                          colors,
                          icon: Icons.block_rounded,
                          title: 'Blocked Strangers',
                          subtitle: '${userState.blockedCount} blocked user(s)',
                          trailing: userState.blockedCount > 0
                              ? TextButton(
                                  onPressed: () async {
                                    await userState.unblockAll();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('All blocked users cleared.')),
                                      );
                                    }
                                  },
                                  child: const Text('Unblock All', style: TextStyle(fontSize: 12)),
                                )
                              : null,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Danger Zone (Logout & Delete Account)
                  _buildSectionHeader(colors, 'DANGER ZONE'),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      children: [
                        if (!userState.isAnonymous) ...[
                          _buildSettingTile(
                            context,
                            colors,
                            icon: Icons.logout_rounded,
                            title: 'Log Out',
                            subtitle: 'Sign out of Google and switch back to guest mode',
                            iconColor: Colors.orangeAccent,
                            onTap: () => _confirmLogout(context, colors),
                          ),
                          Divider(color: colors.divider, height: 1),
                        ],
                        _buildSettingTile(
                          context,
                          colors,
                          icon: Icons.delete_forever_rounded,
                          title: 'Delete Account & Data',
                          subtitle: 'Permanently wipe wallet coins, history & device data',
                          iconColor: Colors.redAccent,
                          titleColor: Colors.redAccent,
                          onTap: () => _confirmDeleteAccount(context, colors),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 5. App Info Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '⚡ HeyOra v1.0.0 (Build 1)',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Safe 1-on-1 Video Matching Platform',
                          style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'support@heyora.app',
                          style: TextStyle(
                            color: colors.primaryCTA,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Sub-Widgets & Helpers ---

  Widget _buildSectionHeader(AppColorScheme colors, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    ThemeMode mode,
    IconData icon,
    AppColorScheme colors,
  ) {
    final isSelected = userState.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => userState.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? colors.primaryCTA : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    AppColorScheme colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? colors.primaryCTA).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? colors.primaryCTA, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  // --- Confirmations & Dialogs ---

  void _confirmLogout(BuildContext context, AppColorScheme colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Log Out from Google?',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You will return to an anonymous guest account. You can reconnect your Google account at any time.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primaryCTA,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await userState.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out. You are now in Guest mode.')),
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AppColorScheme colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Text(
              'Delete Account?',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is PERMANENT and CANNOT be undone.',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              '• All remaining coins and diamonds will be forfeited.\n'
              '• All account credentials and linked Google profiles will be wiped.\n'
              '• Your blocked users list and preferences will be erased.\n'
              '• A brand new guest identity will be assigned.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await userState.deleteAccount();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Account and all associated data have been permanently deleted.'),
                  ),
                );
              }
            },
            child: const Text('PERMANENTLY DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Legal Dialogs ---

  void _showPrivacyPolicyDialog(BuildContext context, AppColorScheme colors) {
    _showLegalModal(
      context,
      colors,
      title: 'Privacy Policy',
      content: '''
**HeyOra Privacy Policy**
*Last updated: October 2026*

**1. Overview**
HeyOra ("we", "our") respects your privacy. This policy describes how we handle information across our 1-on-1 random video platform.

**2. Video & Audio Communication (Peer-to-Peer)**
• All live video and audio streams operate strictly Peer-to-Peer (P2P) via WebRTC.
• **Streams are NEVER recorded, processed, or saved on our servers.**
• Video calls are completely ephemeral and cease to exist the moment a call ends.

**3. Information We Collect**
• **Anonymous Guest UUID:** A random identifier stored locally on your device to track your coin and diamond balances.
• **Google Account (Optional):** If you choose to link Google Sign-In, we store your email address and display name solely to recover your coin purchases across device changes.
• **Moderation Signals:** If you report a user, we store the reported user ID, timestamp, and selected category to enforce device-level bans.

**4. Third-Party Services**
• **Google AdMob:** Delivers rewarded and interstitial ads. AdMob may process non-sensitive device identifiers according to Google's privacy policy.
• **Google Play In-App Purchases:** All financial transactions are processed securely by Google Play. We never see or store credit card details.

**5. Your Rights (Account & Data Deletion)**
Under GDPR, CCPA, and Google Play Data Safety policies, you have the full right to delete your data at any moment. Tapping "Delete Account & Data" in this Settings screen permanently purges your wallet, account association, and device identifiers immediately.

**6. Contact Us**
For privacy inquiries or data requests, contact us at **privacy@heyora.app**.
''',
    );
  }

  void _showTermsOfServiceDialog(BuildContext context, AppColorScheme colors) {
    _showLegalModal(
      context,
      colors,
      title: 'Terms of Service',
      content: '''
**HeyOra Terms of Service**
*Effective Date: October 2026*

**1. 18+ Adult Eligibility**
HeyOra is exclusively intended for adults aged 18 and older. By using HeyOra, you certify under penalty of law that you are at least 18 years of age.

**2. Strict Prohibition of Illegal Content**
We enforce a strict **ZERO-TOLERANCE** policy against:
• Any sexual acts, exposure of genitals, or adult pornography.
• Harassment, bullying, threats, hate speech, or hate symbols.
• Underage individuals appearing anywhere on camera.
• Screen recording or unauthorized distribution of stranger video streams.
• Commercial spam, solicitation, or financial fraud.

**Violation of these rules results in an IMMEDIATE, PERMANENT DEVICE-LEVEL BAN and report to relevant law enforcement.**

**3. Virtual Currency (Coins & Diamonds)**
• Coins and Diamonds are virtual digital goods licensed to you for in-app entertainment.
• They have **no real-world monetary value** and are non-refundable, non-transferable, and non-redeemable for legal currency.
• All in-app purchases are final as processed through Google Play.

**4. Disclaimer & Limitation of Liability**
HeyOra provides matching infrastructure. We do not control the live behavior of strangers. You are responsible for your own safety and may disconnect or block any caller instantly.

**5. Governing Law**
These terms are governed by standard international consumer and digital service regulations.
''',
    );
  }

  void _showCommunityGuidelinesDialog(BuildContext context, AppColorScheme colors) {
    _showLegalModal(
      context,
      colors,
      title: 'Community Guidelines',
      content: '''
**HeyOra Community Guidelines (18+)**

Our mission is to provide an exciting, safe, and respectful environment for meeting new people globally.

**The 3 Golden Rules:**
1. **Respect Consent:** Strangers are real human beings. If someone skips or doesn't want to talk, move on gracefully.
2. **Dress Appropriately:** You must remain fully clothed at all times. Shirtless/suggestive behavior in dim lighting will trigger automated moderation.
3. **Keep It Clean:** No profanity, abusive language, or aggressive demands.

**Instant Safety Actions:**
• **Skip Button:** Jump to the next stranger instantly with zero penalty.
• **Report & Block:** Tap the red shield icon to immediately ban that stranger from ever matching with you again.
• **Safety Blur:** Every call starts with a 3-second safety blur countdown to prevent accidental visual exposure.

**Help Us Keep HeyOra Safe!**
If you witness violations, please report immediately.
''',
    );
  }

  void _showLegalModal(BuildContext context, AppColorScheme colors, {required String title, required String content}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: colors.divider),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      content,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
