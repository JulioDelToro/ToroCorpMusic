import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/services/pdf_script_extractor.dart';

void main() {
  test('PdfScriptExtractor detects chord rows above lyrics and places chords underneath', () {
    const rawPdfText = """
       G            D
De música ligera
""";
    final extractor = PdfScriptExtractor();
    final song = extractor.extractFromRawText(rawPdfText);

    expect(song.lines.isNotEmpty, isTrue);
    final firstLine = song.lines.first;
    expect(firstLine.tokens.any((t) => t.chordUnderneath == "G"), isTrue);
    expect(firstLine.tokens.any((t) => t.chordUnderneath == "D"), isTrue);
  });
}
