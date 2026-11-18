
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
// import 'dart:typed_data';
//
// import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class PdfImportService {

  Future<File?> pickPdf() async {
    final selectedFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (selectedFile == null) {
      return null;
    }

    final path = selectedFile.path;

    if (path == null || path.isEmpty) {
      throw Exception('The selected PDF file could not be accessed.');
    }

    final file = File(path);

    if (!await file.exists()) {
      throw Exception('The selected PDF file no longer exists.');
    }

    return file;
  }


  Future<int> getPageCount(File file) async {
    final document = await PdfDocument.openFile(file.path);

    try {
      return document.pages.length;
    } finally {
      await document.dispose();
    }
  }
  Future<File> renderPageToImage(
      File pdfFile,
      int pageIndex,
      ) async {
    final document = await PdfDocument.openFile(pdfFile.path);

    try {
      if (pageIndex < 0 || pageIndex >= document.pages.length) {
        throw RangeError('Invalid PDF page index: $pageIndex');
      }

      final page = document.pages[pageIndex];

      // Render at approximately 1.5x the PDF's point dimensions.
      final imageWidth = (page.width * 1.5).round();
      final imageHeight = (page.height * 1.5).round();

      final pdfImage = await page.render(
        fullWidth: imageWidth.toDouble(),
        fullHeight: imageHeight.toDouble(),
      );

      if (pdfImage == null) {
        throw Exception('Could not render PDF page ${pageIndex + 1}.');
      }

      try {
        final image = await pdfImage.createImage();
        try {
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );

          if (byteData == null) {
            throw Exception('Could not encode PDF page ${pageIndex + 1}.');
          }

          final directory = await getTemporaryDirectory();
          final outputFile = File(
            '${directory.path}/inkora_pdf_page_${pageIndex + 1}_${DateTime.now().microsecondsSinceEpoch}.png',
          );

          await outputFile.writeAsBytes(
            byteData.buffer.asUint8List(),
            flush: true,
          );

          return outputFile;
        } finally {
          image.dispose();
        }
      } finally {
        pdfImage.dispose();
      }
    } finally {
      await document.dispose();
    }
  }

  Future<List<File>> renderBatch(
      File pdfFile, {
        required int startPage,
        int batchSize = 4,
      }) async {
    if (startPage < 0) {
      throw ArgumentError.value(startPage, 'startPage');
    }

    if (batchSize < 1 || batchSize > 4) {
      throw ArgumentError.value(
        batchSize,
        'batchSize',
        'Batch size must be between 1 and 4.',
      );
    }

    final pageCount = await getPageCount(pdfFile);

    if (startPage >= pageCount) {
      return [];
    }

    final endPage = (startPage + batchSize).clamp(0, pageCount);
    final renderedFiles = <File>[];

    try {
      for (var pageIndex = startPage;
      pageIndex < endPage;
      pageIndex++) {
        final imageFile = await renderPageToImage(
          pdfFile,
          pageIndex,
        );

        renderedFiles.add(imageFile);
      }

      return renderedFiles;
    } catch (_) {
      // Clean up partial results if rendering fails.
      for (final file in renderedFiles) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Preserve the original rendering error.
        }
      }

      rethrow;
    }
  }

  Future<void> testRenderFirstPage(File pdfFile) async {
    final imageFile = await renderPageToImage(pdfFile, 0);

    if (!await imageFile.exists()) {
      throw Exception('Rendered image file was not created.');
    }

    final size = await imageFile.length();

    if (size == 0) {
      throw Exception('Rendered image file is empty.');
    }

    debugPrint('PDF render test passed.');
    debugPrint('Image path: ${imageFile.path}');
    debugPrint('Image size: $size bytes');
  }

}
