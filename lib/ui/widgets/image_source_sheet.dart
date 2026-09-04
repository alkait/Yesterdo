import 'package:flutter/material.dart';

import '../../platform/device_bridge.dart';
import '../branded/branded.dart';

/// Where a picture should come from: the camera, the photo library, or
/// whatever is on the pasteboard. Null when the sheet is swiped away.
enum ImageOrigin { camera, library, paste }

Future<ImageOrigin?> showImageSourceSheet(BuildContext context) =>
    showBrandedSheet<ImageOrigin>(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandedOptionRow(
            key: const ValueKey('image-camera'),
            label: 'Take a picture',
            icon: Icons.photo_camera_outlined,
            onTap: () => Navigator.of(sheetContext).pop(ImageOrigin.camera),
          ),
          const BrandedDivider(),
          BrandedOptionRow(
            key: const ValueKey('image-library'),
            label: 'Choose from photos',
            icon: Icons.photo_library_outlined,
            onTap: () => Navigator.of(sheetContext).pop(ImageOrigin.library),
          ),
          const BrandedDivider(),
          BrandedOptionRow(
            key: const ValueKey('image-paste'),
            label: 'Paste',
            icon: Icons.content_paste_rounded,
            onTap: () => Navigator.of(sheetContext).pop(ImageOrigin.paste),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

/// The bridge call an origin stands for.
Future<String?> fetchImage(DeviceBridge device, ImageOrigin origin) =>
    switch (origin) {
      ImageOrigin.camera => device.pickImage(ImageSource.camera),
      ImageOrigin.library => device.pickImage(ImageSource.library),
      ImageOrigin.paste => device.pasteImage(),
    };
