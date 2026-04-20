import 'package:flutter/material.dart';

const Map<String, Color> _kTagColors = {
  'Politics': Color(0xFF1565C0),
  'Food': Color(0xFFBF360C),
  'Cats': Color(0xFF880E4F),
  'Travel': Color(0xFF00695C),
  'Technology': Color(0xFF1A237E),
  'Business': Color(0xFF4E342E),
  'Lifestyle': Color(0xFF6A1B9A),
  'Sports': Color(0xFF1B5E20),
  'Health': Color(0xFF006064),
  'Entertainment': Color(0xFFB71C1C),
  'Education': Color(0xFF01579B),
  'DIY': Color(0xFF33691E),
  'Fashion': Color(0xFFAD1457),
  'Photography': Color(0xFF37474F),
  'Music': Color(0xFF4527A0),
};

/// Returns the colour assigned to [tag], or a neutral slate if unmapped.
Color tagColor(String tag) => _kTagColors[tag] ?? const Color(0xFF546E7A);

/// A coloured display chip for showing a content tag.
class TagChip extends StatelessWidget {
  final String tag;

  /// When [small] is true, uses slightly smaller font/padding (for list cards).
  final bool small;

  const TagChip({required this.tag, this.small = false, super.key});

  @override
  Widget build(BuildContext context) {
    final color = tagColor(tag);
    return Chip(
      label: Text(
        tag,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.07),
      side: BorderSide(color: color.withValues(alpha: 0.35), width: 1),
      shape: const StadiumBorder(),
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 0)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// A coloured selectable FilterChip for tag filtering.
class TagFilterChip extends StatelessWidget {
  final String tag;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const TagFilterChip({
    required this.tag,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = tagColor(tag);
    return FilterChip(
      label: Text(
        tag,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: color.withValues(alpha: 0.07),
      selectedColor: color.withValues(alpha: 0.18),
      checkmarkColor: color,
      side: BorderSide(
        color: selected ? color : color.withValues(alpha: 0.35),
        width: selected ? 1.5 : 1,
      ),
      shape: const StadiumBorder(),
      showCheckmark: false,
    );
  }
}
