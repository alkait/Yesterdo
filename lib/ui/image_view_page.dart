import 'package:flutter/material.dart';

import 'branded/branded.dart';

/// One picture on its own, to be looked at closely. Pinch to zoom.
class ImageViewPage extends StatelessWidget {
  const ImageViewPage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => BrandedScaffold(
    children: [
      BrandedAppBar(
        leading: BrandedTextButton(
          label: 'Back',
          onTap: () => Navigator.of(context).pop(),
        ),
        center: const BrandedText(
          'Picture',
          role: BrandedTextRole.title,
          align: TextAlign.center,
        ),
      ),
      Expanded(
        child: InteractiveViewer(
          maxScale: Brand.imageMaxZoom,
          child: Center(
            child: Image(image: BrandedImage.load(path), fit: BoxFit.contain),
          ),
        ),
      ),
    ],
  );
}
