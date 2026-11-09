enum ScanFilter { original, grayscale, blackAndWhite }

class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.originalPath,
    this.filter = ScanFilter.original,
    this.quarterTurns = 0,
  });
  final String id;
  final String originalPath;
  final ScanFilter filter;
  final int quarterTurns;

  ScannedPage copyWith({ScanFilter? filter, int? quarterTurns}) => ScannedPage(
    id: id,
    originalPath: originalPath,
    filter: filter ?? this.filter,
    quarterTurns: (quarterTurns ?? this.quarterTurns) % 4,
  );
}
