import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Light segmented control: the selected option is a raised white pill.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.background = AppColors.segment,
    this.expand = true,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color background;

  /// Fill the width with equal segments; otherwise size to the labels.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          spacing: 4,
          children: [
            for (final (value, label) in options)
              if (expand)
                Expanded(child: _segment(value, label))
              else
                _segment(value, label),
          ],
        ),
      ),
    );
  }

  Widget _segment(T value, String label) {
    final isSelected = value == selected;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppColors.surface : Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: isSelected ? 1 : 0,
        shadowColor: const Color(0x4012141A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(value),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: expand ? 4 : 14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggleable chip that turns dark when selected.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.semanticsLabel,
    this.borderRadius = 22,
    this.padding,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final String? semanticsLabel;
  final double borderRadius;

  /// Defaults to 12px sides (6px on the left when there is a [leading]).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Semantics(
      selected: selected,
      button: true,
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: selected ? AppColors.ink : AppColors.segment,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: padding ?? EdgeInsets.only(left: leading == null ? 12 : 6, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  ?leading,
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
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

/// 44px circular icon button for steppers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Grey fill instead of a white button with an outline.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: filled ? AppColors.segment : AppColors.surface,
        disabledBackgroundColor: filled ? AppColors.segment : AppColors.surface,
        foregroundColor: AppColors.ink,
        disabledForegroundColor: AppColors.ink.withValues(alpha: 0.3),
        side: filled ? null : const BorderSide(color: AppColors.line),
      ),
    );
  }
}

/// `Эхлэх   [−] 09:00 [+]`.
class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementTooltip,
    required this.incrementTooltip,
  });

  final String label;
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String decrementTooltip;
  final String incrementTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        RoundIconButton(icon: Icons.remove_rounded, tooltip: decrementTooltip, onPressed: onDecrement),
        SizedBox(width: 80, child: Text(value, textAlign: TextAlign.center, style: AppText.numeric(16))),
        RoundIconButton(icon: Icons.add_rounded, tooltip: incrementTooltip, onPressed: onIncrement),
      ],
    );
  }
}

/// Grey bar with − and + at the ends and a caption between.
class StepperBar extends StatelessWidget {
  const StepperBar({
    super.key,
    required this.caption,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementTooltip,
    required this.incrementTooltip,
  });

  final String caption;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String decrementTooltip;
  final String incrementTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.remove_rounded, tooltip: decrementTooltip, onPressed: onDecrement),
          Expanded(child: Text(caption, textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 13))),
          RoundIconButton(icon: Icons.add_rounded, tooltip: incrementTooltip, onPressed: onIncrement),
        ],
      ),
    );
  }
}
