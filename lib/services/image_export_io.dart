import 'dart:io';
import 'dart:typed_data';
import 'image_export_models.dart';

Future<ExportResult> saveImageToDevice(Uint8List bytes, String fileName) async {
  try {
    Directory? targetDir;

    if (Platform.isAndroid) {
      // 1. Primary: Public device Download folder
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (publicDownload.existsSync()) {
        targetDir = publicDownload;
      } else {
        // 2. Secondary: Public Pictures/DIP_Studio folder
        final dipPictures = Directory('/storage/emulated/0/Pictures/DIP_Studio');
        try {
          if (!dipPictures.existsSync()) {
            dipPictures.createSync(recursive: true);
          }
          targetDir = dipPictures;
        } catch (_) {
          targetDir = Directory('/storage/emulated/0/Pictures');
        }
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final winDownloads = Directory('$userProfile\\Downloads');
        if (winDownloads.existsSync()) {
          targetDir = winDownloads;
        } else {
          final winPictures = Directory('$userProfile\\Pictures');
          if (winPictures.existsSync()) {
            targetDir = winPictures;
          }
        }
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final unixDownloads = Directory('$home/Downloads');
        if (unixDownloads.existsSync()) {
          targetDir = unixDownloads;
        }
      }
    }

    targetDir ??= Directory.current;

    final separator = Platform.isWindows ? '\\' : '/';
    final filePath = '${targetDir.path}$separator$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(
      success: true,
      filePath: filePath,
      message: 'Photo saved successfully to: $filePath',
      canShare: false,
    );
  } catch (e) {
    try {
      final fallbackPath = fileName;
      final file = File(fallbackPath);
      await file.writeAsBytes(bytes, flush: true);
      return ExportResult(
        success: true,
        filePath: file.absolute.path,
        message: 'Saved to working folder: ${file.absolute.path}',
        canShare: false,
      );
    } catch (err) {
      return ExportResult(
        success: false,
        filePath: '',
        message: 'Failed to save image: $err',
        canShare: false,
      );
    }
  }
}

Future<void> shareExportedImage(String filePath) async {
  // Share hook
}
