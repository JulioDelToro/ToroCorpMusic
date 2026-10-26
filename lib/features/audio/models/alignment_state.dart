/// Estado en tiempo real de la posición de la letra que se va cantando.
class AlignmentState {
  final int currentLineIndex;
  final int currentWordIndex;
  final double confidence;
  final String lastSpokenWord;
  final bool isSinging;

  const AlignmentState({
    this.currentLineIndex = 0,
    this.currentWordIndex = 0,
    this.confidence = 1.0,
    this.lastSpokenWord = '',
    this.isSinging = false,
  });

  AlignmentState copyWith({
    int? currentLineIndex,
    int? currentWordIndex,
    double? confidence,
    String? lastSpokenWord,
    bool? isSinging,
  }) {
    return AlignmentState(
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      confidence: confidence ?? this.confidence,
      lastSpokenWord: lastSpokenWord ?? this.lastSpokenWord,
      isSinging: isSinging ?? this.isSinging,
    );
  }

  @override
  String toString() {
    return 'AlignmentState(line: $currentLineIndex, word: $currentWordIndex, singing: $isSinging)';
  }
}
