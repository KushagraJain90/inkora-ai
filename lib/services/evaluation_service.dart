
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class EvaluationApiResponse {
  final Uint8List pdfBytes;
  final double totalMarks;
  final double marksAwarded;
  final String feedbackSummary;
  final String scoreRationale;
  final String? status;
  final String? fileName;

  const EvaluationApiResponse({
    required this.pdfBytes,
    required this.totalMarks,
    required this.marksAwarded,
    required this.feedbackSummary,
    required this.scoreRationale,
    this.status,
    this.fileName,
  });
}

class EvaluationService {
  EvaluationService({
    http.Client? client,
    this.baseUrl = 'https://inkora-ai-backend.onrender.com',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  String _decodeHeader(String? value, String fallback) {
    if (value == null || value.isEmpty) {
      return fallback;
    }

    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }
  Future<EvaluationApiResponse> evaluate({
    String? questionText,
    XFile? questionImage,
    String? studentAnswerText,
    List<XFile> studentAnswerImages = const [],
    required double totalMarks,
    required String academicLevel,
    required String degreeField,
  }) async {
    // Validate question input: exactly one input mode.
    final hasQuestionText = questionText?.trim().isNotEmpty ?? false;
    final hasQuestionImage = questionImage != null;

    if (hasQuestionText == hasQuestionImage) {
      throw ArgumentError(
        'Provide either question text or one question image.',
      );
    }

    // Validate student answer input: exactly one input mode.
    final hasAnswerText =
        studentAnswerText?.trim().isNotEmpty ?? false;
    final hasAnswerImages = studentAnswerImages.isNotEmpty;

    if (hasAnswerText == hasAnswerImages) {
      throw ArgumentError(
        'Provide either student answer text or answer images.',
      );
    }

    if (totalMarks <= 0) {
      throw ArgumentError('Total marks must be greater than zero.');
    }

    if (academicLevel.trim().isEmpty) {
      throw ArgumentError('Academic level is required.');
    }

    if (degreeField.trim().isEmpty) {
      throw ArgumentError('Degree field is required.');
    }

    if (studentAnswerImages.length > 100) {
      throw ArgumentError('A maximum of 100 answer images is allowed.');
    }

    final uri = Uri.parse('$baseUrl/api/evaluate');

    final request = http.MultipartRequest('POST', uri);

    // Common evaluation fields.
    request.fields.addAll({
      'total_marks': totalMarks.toString(),
      'academic_level': academicLevel.trim(),
      'degree_field': degreeField.trim(),
    });

    // Question input.
    if (hasQuestionText) {
      request.fields['question_text'] = questionText!.trim();
    } else {
      request.files.add(
        await _imageToMultipart(
          questionImage!,
          'question_image',
        ),
      );
    }

    // Student answer input.
    if (hasAnswerText) {
      request.fields['student_answer_text'] =
          studentAnswerText!.trim();
    } else {
      // Repeated field name: student_answer_images
      // Preserves the selected page order.
      for (final image in studentAnswerImages) {
        request.files.add(
          await _imageToMultipart(
            image,
            'student_answer_images',
          ),
        );
      }
    }

    try {
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw EvaluationException(
          _extractErrorMessage(response),
          statusCode: response.statusCode,
        );
      }

      final contentType =
          response.headers['content-type']?.toLowerCase() ?? '';

      if (!contentType.contains('application/pdf')) {
        throw EvaluationException(
          'The server response was successful, but it did not contain a PDF.',
          statusCode: response.statusCode,
        );
      }

      if (response.bodyBytes.isEmpty) {
        throw EvaluationException('The generated PDF is empty.');
      }

      final headers = response.headers;

      return EvaluationApiResponse(
        pdfBytes: response.bodyBytes,
        totalMarks: _parseDouble(headers['x-total-marks']),
        marksAwarded: _parseDouble(headers['x-marks-awarded']),
        feedbackSummary: _decodeHeader(
          headers['x-feedback-summary'],
          'No feedback summary available.',
        ),
        scoreRationale: _decodeHeader(
          headers['x-score-rationale'],
          'No score rationale available.',
        ),
        status: headers['x-evaluation-status'],
        fileName: _extractFileName(
          headers['content-disposition'],
        ),
      );
    } on EvaluationException {
      rethrow;
    } catch (e) {
      throw EvaluationException(
        'Unable to connect to the evaluation server. '
            'Check your network connection and backend server. Details: $e',
      );
    }
  }

  Future<http.MultipartFile> _imageToMultipart(
      XFile image,
      String fieldName,
      ) async {
    final extension = p.extension(image.path).toLowerCase();

    final mimeType = image.mimeType ?? _mimeTypeFromExtension(extension);

    return http.MultipartFile.fromPath(
      fieldName,
      image.path,
      contentType: MediaType.parse(mimeType),
    );
  }

  String _mimeTypeFromExtension(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  double _parseDouble(String? value) {
    return double.tryParse(value ?? '') ?? 0.0;
  }

  String? _extractFileName(String? contentDisposition) {
    if (contentDisposition == null) return null;

    final match = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    return match?.group(1);
  }

  String _extractErrorMessage(http.Response response) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return 'Evaluation failed with HTTP ${response.statusCode}.';
    }

    return 'Evaluation failed (${response.statusCode}): $body';
  }

  void dispose() {
    _client.close();
  }
}

class EvaluationException implements Exception {
  final String message;
  final int? statusCode;

  const EvaluationException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() => message;
}
