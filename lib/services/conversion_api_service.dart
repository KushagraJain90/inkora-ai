
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ConvertedDocuments {
  final String wordPath;
  final String pdfPath;

  const ConvertedDocuments({
    required this.wordPath,
    required this.pdfPath,
  });
}

class ConversionApiService {
  // Use the PC LAN IP that already worked on your phone.
  static const String baseUrl = 'https://inkora-ai-backend.onrender.com';

  Future<ConvertedDocuments> convertPages(List<XFile> pages) async {
    if (pages.isEmpty) {
      throw Exception('Select at least one handwritten page.');
    }

    if (pages.length > 100) {
      throw Exception('You can convert a maximum of 100 pages.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/convert'),
    );

    for (final page in pages) {
      final extension = page.name.toLowerCase().split('.').last;

      final mediaType = switch (extension) {
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        'png' => MediaType('image', 'png'),
        'webp' => MediaType('image', 'webp'),
        _ => null,
      };

      if (mediaType == null) {
        throw Exception(
          'Unsupported image format: ${page.name}. '
              'Use JPG, PNG, or WebP.',
        );
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'pages',
          page.path,
          filename: page.name,
          contentType: mediaType,
        ),
      );
    }

    final streamed = await request.send().timeout(
      const Duration(minutes: 10),
    );

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(
        'Conversion failed (${response.statusCode}): '
            '${response.body}',
      );
    }

    if (!(response.headers['content-type'] ?? '')
        .toLowerCase()
        .contains('application/zip')) {
      throw Exception('The server did not return a ZIP file.');
    }

    // Extract the ZIP returned by FastAPI.
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);

    final wordFile = archive.files.where(
          (file) =>
      file.isFile &&
          file.name.split('/').last == 'Inkora_AI_Converted.docx',
    );

    final pdfFile = archive.files.where(
          (file) =>
      file.isFile &&
          file.name.split('/').last == 'Inkora_AI_Converted.pdf',
    );

    if (wordFile.isEmpty || pdfFile.isEmpty) {
      throw Exception('The ZIP does not contain both expected documents.');
    }

    final appDirectory = await getApplicationDocumentsDirectory();

    final convertedRoot = Directory(
      '${appDirectory.path}/InkoraAI/Converted',
    );

    await convertedRoot.create(recursive: true);

// Give every conversion its own directory.
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    var outputDirectory = Directory(
      '${convertedRoot.path}/$timestamp',
    );

    var suffix = 1;

    while (await outputDirectory.exists()) {
      outputDirectory = Directory(
        '${convertedRoot.path}/${timestamp}_$suffix',
      );
      suffix++;
    }

    await outputDirectory.create();

    final wordPath =
        '${outputDirectory.path}/Inkora_AI_Converted.docx';

    final pdfPath =
        '${outputDirectory.path}/Inkora_AI_Converted.pdf';

    final wordBytes = wordFile.first.content as List<int>;
    final pdfBytes = pdfFile.first.content as List<int>;

    await File(wordPath).writeAsBytes(wordBytes, flush: true);
    await File(pdfPath).writeAsBytes(pdfBytes, flush: true);

    return ConvertedDocuments(
      wordPath: wordPath,
      pdfPath: pdfPath,
    );
  }
}
