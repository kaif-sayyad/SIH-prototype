import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class GovernmentHeader extends StatelessWidget {
  final String currentLang;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback? onLogout;

  const GovernmentHeader({
    Key? key,
    required this.currentLang,
    required this.onLanguageChanged,
    this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = AppConstants.i18n[currentLang]!;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B365D), // Deep Gov Navy
        border: Border(bottom: BorderSide(color: Color(0xFFFF9933), width: 3.5)), // Saffron accent
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Emblem & Skill India branding
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4),
                ],
              ),
              child: const Center(
                child: Text(
                  '🇮🇳',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t['portal_title'] ?? 'SkillPath Family Counselling Portal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    t['portal_sub'] ?? 'Ministry of Skill Development & Entrepreneurship',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Bilingual Switcher (English / Marathi)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => onLanguageChanged('en'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentLang == 'en' ? const Color(0xFFFF9933) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'EN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: currentLang == 'en' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => onLanguageChanged('mr'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentLang == 'mr' ? const Color(0xFFFF9933) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'मराठी',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: currentLang == 'mr' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (onLogout != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                tooltip: 'Logout',
                onPressed: onLogout,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
