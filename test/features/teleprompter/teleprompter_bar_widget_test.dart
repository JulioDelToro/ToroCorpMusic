import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/teleprompter_bar_widget.dart';

void main() {
  testWidgets('TeleprompterBar displays lyrics on top and chords on bottom row', (tester) async {
    final song = SongScript(lines: [
      const LyricLine(tokens: [LyricToken(word: "Hola", chordUnderneath: "Sol")])
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeleprompterBarWidget(
          song: song,
          activeLineIndex: 0,
          activeWordIndex: 0,
        ),
      ),
    ));

    expect(find.text("Hola"), findsOneWidget);
    expect(find.text("Sol"), findsOneWidget);
  });
}
