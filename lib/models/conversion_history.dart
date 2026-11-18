
class ConversionHistory {
  final String id;
  final String documentName;
  final String wordPath;
  final String pdfPath;
  final DateTime createdAt;
  final int pageCount;

  const ConversionHistory({
    required this.id,
    required this.documentName,
    required this.wordPath,
    required this.pdfPath,
    required this.createdAt,
    required this.pageCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentName': documentName,
      'wordPath': wordPath,
      'pdfPath': pdfPath,
      'createdAt': createdAt.toIso8601String(),
      'pageCount': pageCount,
    };
  }

  factory ConversionHistory.fromJson(Map<String, dynamic> json) {
    return ConversionHistory(
      id: json['id'] as String,
      documentName: json['documentName'] as String,
      wordPath: json['wordPath'] as String,
      pdfPath: json['pdfPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pageCount: json['pageCount'] as int,
    );
  }
}
