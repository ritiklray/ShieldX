import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool?> showGuardianPermissionDialog(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _GuardianPermissionModal(),
  );
}

class _GuardianPermissionModal extends StatelessWidget {
  const _GuardianPermissionModal();

  @override
  Widget build(BuildContext context) {
    const Color bg1 = Color(0xFF0A0F1E);
    const Color cardBg = Color(0xFF111D3A);
    const Color accentBlue = Color(0xFF3B8BFF);
    const Color shieldGreen = Color(0xFF00C48C);
    const Color errorRed = Color(0xFFFF4C6A);
    const Color textPrimary = Color(0xFFFFFFFF);
    const Color textSecondary = Color(0xFFB0BCDA);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1E2E52), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2E52),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shieldGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: shieldGreen.withOpacity(0.4)),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: shieldGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Guardian Protection',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Real-time automated safety system',
                      style: TextStyle(
                        color: shieldGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'How it protects you:',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          _buildFeature(
            icon: Icons.vibration_rounded,
            color: const Color(0xFFF5C518),
            title: 'Shake to SOS',
            desc:
                'Shake your phone 3 times rapidly to trigger SOS automatically without opening the app.',
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),
          _buildFeature(
            icon: Icons.mic_rounded,
            color: accentBlue,
            title: 'Voice Activation',
            desc:
                'Scream or say "Help", "Bachao", etc. to silently activate emergency mode.',
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),
          _buildFeature(
            icon: Icons.bolt_rounded,
            color: errorRed,
            title: 'Auto Action',
            desc:
                'Immediately calls your emergency contact, shares your live location & alerts contacts.',
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 24),
          const Text(
            'Required Permissions:',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPerm(Icons.mic, 'Microphone'),
              _buildPerm(Icons.location_on, 'Location'),
              _buildPerm(Icons.contacts, 'Contacts'),
              _buildPerm(Icons.phone, 'Call'),
            ],
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF1E2E52)),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Request actual system permissions sequentially or together
                    final Map<Permission, PermissionStatus> statuses = await [
                      Permission.microphone,
                      Permission.location,
                      Permission.contacts,
                      Permission.phone,
                      Permission.sms,
                      Permission.notification,
                    ].request();

                    if (!context.mounted) return;

                    bool allGranted = true;
                    bool anyPermanentlyDenied = false;

                    for (final status in statuses.values) {
                      if (status.isPermanentlyDenied) {
                        anyPermanentlyDenied = true;
                      }
                      if (!status.isGranted) {
                        allGranted = false;
                      }
                    }

                    if (anyPermanentlyDenied) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Permissions permanently denied. Please enable them in Settings.',
                          ),
                          backgroundColor: errorRed.withOpacity(0.9),
                          action: SnackBarAction(
                            label: 'Settings',
                            textColor: Colors.white,
                            onPressed: () => openAppSettings(),
                          ),
                        ),
                      );
                      Navigator.pop(context, false);
                      return;
                    }

                    if (allGranted) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'All permissions are required for AI Guardian to work.',
                          ),
                          backgroundColor: const Color(
                            0xFFF5C518,
                          ).withOpacity(0.9),
                        ),
                      );
                      Navigator.pop(context, false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: shieldGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Grant & Enable',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2E52)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerm(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFB0BCDA), size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB0BCDA),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
