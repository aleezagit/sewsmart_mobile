import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

// Asks for a photo from the camera or the gallery and returns it, or null
// when the user cancels. Large photos are scaled down and sent as JPEG, which
// the backend accepts up to 5 MB.
Future<XFile?> pickImage(BuildContext context, {String title = 'Add a photo'}) async {
  final ImageSource? source = kIsWeb
      ? ImageSource.gallery
      : await showModalBottomSheet<ImageSource>(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              ListTile(
                leading: Icon(Icons.photo_camera_rounded, color: AppColors.primaryLight),
                title: Text('Take a photo', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: AppColors.primaryLight),
                title: Text('Choose from gallery', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
  if (source == null) return null;
  return ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
}
