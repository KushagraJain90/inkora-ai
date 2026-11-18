
class EvaluationResult {
  final String title;
  final double totalMarks;
  final double marksAwarded;
  final String feedbackSummary;
  final String scoreRationale;
  final String pdfPath;
  final DateTime createdAt;

  const EvaluationResult({
    required this.title,
    required this.totalMarks,
    required this.marksAwarded,
    required this.feedbackSummary,
    required this.scoreRationale,
    required this.pdfPath,
    required this.createdAt,
  });

  double get percentage {
    if (totalMarks <= 0) return 0;
    return (marksAwarded / totalMarks) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'totalMarks': totalMarks,
      'marksAwarded': marksAwarded,
      'feedbackSummary': feedbackSummary,
      'scoreRationale': scoreRationale,
      'pdfPath': pdfPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EvaluationResult.fromMap(Map<String, dynamic> map) {
    return EvaluationResult(
      title: map['title'] as String,
      totalMarks: (map['totalMarks'] as num).toDouble(),
      marksAwarded: (map['marksAwarded'] as num).toDouble(),
      feedbackSummary: map['feedbackSummary'] as String,
      scoreRationale: map['scoreRationale'] as String,
      pdfPath: map['pdfPath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
