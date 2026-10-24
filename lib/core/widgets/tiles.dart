import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_visuals.dart';
import '../theme/app_colors.dart';

/// The app's real icon when known, else a letter tile.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.appId,
    required this.name,
    this.icon,
    this.size = 40,
    this.dimmed = false,
  });

  final String appId;
  final String name;

  /// PNG bytes from the platform.
  final Uint8List? icon;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon != null) {
      final image = Image.memory(icon, width: size, height: size, gaplessPlayback: true);
      return ExcludeSemantics(
        child: dimmed
            ? ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: image)
            : image,
      );
    }
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dimmed ? AppColors.inactive : appTileColor(appId),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          name.characters.first,
          style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}
