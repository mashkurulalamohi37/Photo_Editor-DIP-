import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'image_export_models.dart';

Future<ExportResult> saveImageToDevice(Uint8List bytes, String fileName) async {
  try {
    final jsArray = bytes.toJS;
    final blob = web.Blob(
      [jsArray].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;

    anchor.click();
    web.URL.revokeObjectURL(url);

    return ExportResult(
      success: true,
      filePath: fileName,
      message: 'Photo downloaded to your browser downloads folder: $fileName',
      canShare: false,
    );
  } catch (e) {
    return ExportResult(
      success: false,
      filePath: '',
      message: 'Failed to download image on web: $e',
      canShare: false,
    );
  }
}

Future<void> shareExportedImage(String filePath) async {
  // Web sharing not supported via file path
}
