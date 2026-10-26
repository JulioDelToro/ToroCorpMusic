/// Representa una palabra en el teleprompter y su nota musical o acorde inferior de apoyo.
class LyricToken {
  final String word;
  final String? chordUnderneath;

  const LyricToken({
    required this.word,
    this.chordUnderneath,
  });

  LyricToken copyWith({
    String? word,
    String? chordUnderneath,
  }) {
    return LyricToken(
      word: word ?? this.word,
      chordUnderneath: chordUnderneath ?? this.chordUnderneath,
    );
  }

  @override
  String toString() => 'LyricToken(word: $word, chordUnderneath: $chordUnderneath)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LyricToken &&
        other.word == word &&
        other.chordUnderneath == chordUnderneath;
  }

  @override
  int get hashCode => Object.hash(word, chordUnderneath);
}
