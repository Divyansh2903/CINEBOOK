import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/ai_icon.dart';

//Floating, rounded navigation bar with an active gold-pill highlight.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = [
    _TabSpec(Icons.movie_filter, Icons.movie_filter_outlined, 'PREMIERE'),
    _TabSpec(Icons.search, Icons.search, 'SEARCH'),
    _TabSpec(Icons.confirmation_number, Icons.confirmation_number_outlined, 'BOOK'),
    _TabSpec(Icons.auto_awesome, Icons.auto_awesome, 'CHAT', isAi: true),
    _TabSpec(Icons.person, Icons.person_outline, 'PROFILE'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.25),
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _TabButton(
                      spec: _tabs[i],
                      active: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.active, this.inactive, this.label, {this.isAi = false});
  final IconData active;
  final IconData inactive;
  final String label;
  final bool isAi;
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.spec, required this.active, required this.onTap});
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.secondaryFixedDim;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              spec.isAi
                  ? AiIcon(size: 22, color: color)
                  : Icon(active ? spec.active : spec.inactive, color: color, size: 22),
              const SizedBox(height: 5),
              //Scale-down keeps long labels (e.g. PREMIERE) from clipping.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spec.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
