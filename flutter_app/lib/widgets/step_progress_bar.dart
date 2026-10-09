import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int maxUnlockedStep;
  final String lang;
  final ValueChanged<int> onStepSelected;

  const StepProgressBar({
    Key? key,
    required this.currentStep,
    required this.maxUnlockedStep,
    required this.lang,
    required this.onStepSelected,
  }) : super(key: key);

  static const List<String> stepKeys = [
    'nav_step1',
    'nav_step2',
    'nav_step3',
    'nav_step4',
    'nav_step5',
    'nav_step6',
    'nav_step7',
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppConstants.i18n[lang]!;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(stepKeys.length, (index) {
            final isCurrent = index == currentStep;
            final isUnlocked = index <= maxUnlockedStep;
            final label = t[stepKeys[index]] ?? 'Step ${index + 1}';

            return Row(
              children: [
                InkWell(
                  onTap: isUnlocked ? () => onStepSelected(index) : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF1B365D)
                          : (isUnlocked ? Colors.blue.shade50 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFFF9933)
                            : (isUnlocked ? Colors.blue.shade200 : Colors.grey.shade300),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: isCurrent
                              ? const Color(0xFFFF9933)
                              : (isUnlocked ? Colors.blue.shade700 : Colors.grey.shade400),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : (isUnlocked ? const Color(0xFF1B365D) : Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < stepKeys.length - 1)
                  Container(
                    width: 14,
                    height: 2,
                    color: index < maxUnlockedStep ? const Color(0xFFFF9933) : Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
