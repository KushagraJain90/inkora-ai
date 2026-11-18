enum DocumentPageSource {
  gallery,
  camera,
  pdf,
}

class DocumentPage {
  const DocumentPage({
    required this.imagePath,
    required this.pageNumber,
    required this.source,
  }) : assert(pageNumber > 0);

  /// Local path of the image representing this page.
  final String imagePath;

  /// One-based page number in the document.
  final int pageNumber;

  /// Where the page originated.
  final DocumentPageSource source;

  @override
  String toString() {
    return 'DocumentPage('
        'pageNumber: $pageNumber, '
        'source: ${source.name}, '
        'imagePath: $imagePath)';
  }
}
