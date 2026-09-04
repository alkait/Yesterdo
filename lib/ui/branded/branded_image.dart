import 'dart:io';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'branded_icon.dart';

/// A picture from the images folder, rounded like a card. Drawn at the
/// width it is given and no taller than [Brand.imageMaxHeight], unless
/// [thumbnail], which is a small square. A picture whose file has gone
/// shows a placeholder rather than an error.
class BrandedImage extends StatelessWidget {
  const BrandedImage({
    super.key,
    required this.path,
    this.thumbnail = false,
    this.onTap,
  });

  final String path;
  final bool thumbnail;
  final VoidCallback? onTap;

  /// How a path becomes a picture. Tests bind a loader that hands back a
  /// ready-made one, since decoding a file never completes under the
  /// widget tester's clock.
  static ImageProvider Function(String path) load = (path) =>
      FileImage(File(path));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = thumbnail ? Brand.thumbnailSize : null;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          thumbnail ? Brand.thumbnailRadius : Brand.cardRadius,
        ),
        child: Container(
          width: size,
          height: size,
          // Never shorter than a tap target, so a tiny picture still
          // has room for the button laid over it in the editor.
          constraints: thumbnail
              ? null
              : const BoxConstraints(
                  minHeight: Brand.tapTarget,
                  maxHeight: Brand.imageMaxHeight,
                ),
          color: scheme.surfaceContainerHighest,
          child: Image(
            image: load(path),
            fit: thumbnail ? BoxFit.cover : BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stack) =>
                const Center(child: BrandedIcon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}
