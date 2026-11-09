import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/errors/app_failure.dart';
import '../domain/scanned_page.dart';

class ScanProcessing {
  Future<void> normalize(String source, String target) => Isolate.run(() {
    final file = File(source);
    if (file.lengthSync() > 30 * 1024 * 1024) {
      throw const AppFailure('Choose images smaller than 30 MiB each.');
    }
    final bytes = file.readAsBytesSync();
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width * info.height > 24000000) {
      throw const AppFailure(
        'This image is unsupported or too large. Use JPEG or PNG images up to 24 megapixels.',
      );
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) {
      throw const AppFailure('This image could not be read.');
    }
    var image = img.bakeOrientation(decoded);
    final scale = math.min(1.0, 2200 / math.max(image.width, image.height));
    if (scale < 1) {
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
      );
    }
    final white = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    );
    img.fill(white, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(white, image);
    File(target)
        .writeAsBytesSync(img.encodeJpg(white, quality: 90), flush: true);
  });

  Future<String> preview(ScannedPage page, String target) => Isolate.run(() {
    if (File(target).existsSync()) return target;
    final image = _render(page);
    File(target)
        .writeAsBytesSync(img.encodeJpg(image, quality: 85), flush: true);
    return target;
  });

  Future<String> pdf(List<ScannedPage> pages, String target) => Isolate.run(
    () async {
      if (pages.isEmpty) {
        throw const AppFailure('Add at least one page before creating a PDF.');
      }
      final document = pw.Document(compress: true);
      for (final page in pages) {
        var image = _render(page);
        final scale = math.min(1.0, 1754 / math.max(image.width, image.height));
        if (scale < 1) {
          image = img.copyResize(
            image,
            width: (image.width * scale).round(),
            height: (image.height * scale).round(),
          );
        }
        final pdfImage = pw.MemoryImage(img.encodeJpg(image, quality: 75));
        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (_) =>
                pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
          ),
        );
      }
      final bytes = await document.save();
      await File(target).writeAsBytes(bytes, flush: true);
      return target;
    },
  );
}

img.Image _render(ScannedPage page) {
  var image = img.decodeImage(File(page.originalPath).readAsBytesSync());
  if (image == null) {
    throw const AppFailure(
      'A scan image is missing or unreadable. Remove it and scan the page again.',
    );
  }
  if (page.quarterTurns != 0) {
    image = img.copyRotate(image, angle: 90 * page.quarterTurns);
  }
  return switch (page.filter) {
    ScanFilter.original => image,
    ScanFilter.grayscale => img.grayscale(image),
    ScanFilter.blackAndWhite => img.luminanceThreshold(image),
  };
}
