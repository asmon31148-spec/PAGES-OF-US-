import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class RomanceKeypad extends StatelessWidget {
  final String enteredPin;
  final int pinLength;
  final bool isError;
  final String? hint;
  final String title;
  final String subtitle;
  final Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const RomanceKeypad({
    super.key,
    required this.enteredPin,
    this.pinLength = 6,
    this.isError = false,
    this.hint,
    required this.title,
    required this.subtitle,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title & Subtitle
        Text(
          title,
          style: const TextStyle(
            color: AppColors.romanceInk,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.romanceSoft,
            fontSize: 12.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Secret Riddle / Clue Card if available
        if (hint != null && hint!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.romanceWine.withOpacity(0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.romanceRoseGold.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key_rounded, color: AppColors.romanceGold, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Clue: $hint',
                    style: const TextStyle(
                      color: AppColors.romanceGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 6 PIN Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pinLength, (index) {
            final isFilled = index < enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isError
                    ? const Color(0xFFF87171)
                    : (isFilled ? AppColors.romanceRoseGold : Colors.transparent),
                border: Border.all(
                  color: isError
                      ? const Color(0xFFF87171)
                      : (isFilled ? AppColors.romanceRoseGold : AppColors.romanceBorder),
                  width: 1.5,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: AppColors.romanceRoseGold.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            );
          }),
        ),

        const SizedBox(height: 32),

        // Keypad Grid (1-9, Clear, 0, Backspace)
        Column(
          children: [
            _buildRow(['1', '2', '3']),
            const SizedBox(height: 14),
            _buildRow(['4', '5', '6']),
            const SizedBox(height: 14),
            _buildRow(['7', '8', '9']),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionKey(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onClear();
                  },
                ),
                const SizedBox(width: 24),
                _buildDigitKey('0'),
                const SizedBox(width: 24),
                _buildActionKey(
                  icon: Icons.backspace_outlined,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildDigitKey(d),
        );
      }).toList(),
    );
  }

  Widget _buildDigitKey(String digit) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onDigit(digit);
      },
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.romanceCard,
          border: Border.all(color: AppColors.romanceBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            color: AppColors.romanceInk,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.romanceSoft, size: 24),
      ),
    );
  }
}
