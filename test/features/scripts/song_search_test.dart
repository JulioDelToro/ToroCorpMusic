import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/constants/app_colors.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';
import 'package:toro_music_teleprompter/features/scripts/presentation/song_preview_sheet.dart';
import 'package:toro_music_teleprompter/features/scripts/presentation/song_search_dialog.dart';
import 'package:toro_music_teleprompter/features/scripts/services/preloaded_songs_catalog.dart';
import 'package:toro_music_teleprompter/features/scripts/services/saved_songs_service.dart';
import 'package:toro_music_teleprompter/features/scripts/services/song_search_service.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R5 & R7: Preloaded Songs Catalog (20 Popular Hits)', () {
    test('Catalog contains exactly 20 preloaded iconic hits', () {
      expect(PreloadedSongsCatalog.songs.length, equals(20));
    });

    test('All 20 required iconic hits exist in the catalog by title', () {
      final requiredTitles = [
        'De Música Ligera',
        'La Bamba',
        'Cielito Lindo',
        'Guantanamera',
        'Bésame Mucho',
        'Amor Eterno',
        'Rayando el Sol',
        'Oye Cómo Va',
        'Lamento Boliviano',
        'Stand by Me',
        'Hotel California',
        'Let It Be',
        'Yesterday',
        "Knockin' on Heaven's Door",
        'El Rey',
        'Volver Volver',
        'Color Esperanza',
        'Mi Gente',
        'Despacito',
        'Eres',
      ];

      for (final title in requiredTitles) {
        final matches = PreloadedSongsCatalog.searchCatalog(title);
        expect(
          matches.any((s) => s.title.toLowerCase().contains(title.toLowerCase())),
          isTrue,
          reason: 'Catalog must include "$title"',
        );
      }
    });

    test('Every catalog song parses into a valid SongScript with lines and tokens', () {
      for (final song in PreloadedSongsCatalog.songs) {
        final script = song.toSongScript();
        expect(script.title, equals(song.title));
        expect(script.artist, equals(song.artist));
        expect(script.lines.isNotEmpty, isTrue, reason: '${song.title} must have parsed lines');

        final allTokens = script.allTokens;
        expect(allTokens.isNotEmpty, isTrue, reason: '${song.title} must have tokens');

        // Verify that chords are present in the song
        final hasChords = allTokens.any((t) => t.chordUnderneath != null && t.chordUnderneath!.isNotEmpty);
        expect(hasChords, isTrue, reason: '${song.title} must contain bracketed ChordPro chords');
      }
    });

    test('Search by artist returns matching songs', () {
      final sodaMatches = PreloadedSongsCatalog.searchCatalog('Soda Stereo');
      expect(sodaMatches.isNotEmpty, isTrue);
      expect(sodaMatches.first.title, equals('De Música Ligera'));

      final beatlesMatches = PreloadedSongsCatalog.searchCatalog('Beatles');
      expect(beatlesMatches.length, equals(2));
      expect(beatlesMatches.map((s) => s.title), containsAll(['Let It Be', 'Yesterday']));
    });

    test('Search by lyric fragment returns matching song', () {
      final matches = PreloadedSongsCatalog.searchCatalog('calor de las masas');
      expect(matches.isNotEmpty, isTrue);
      expect(matches.first.title, equals('De Música Ligera'));

      final cielitoMatches = PreloadedSongsCatalog.searchCatalog('Sierra Morena');
      expect(cielitoMatches.isNotEmpty, isTrue);
      expect(cielitoMatches.first.title, equals('Cielito Lindo'));
    });

    test('Accent-insensitive and case-insensitive search works seamlessly', () {
      // Searching "musica" without accent should find "De Música Ligera"
      final noAccent = PreloadedSongsCatalog.searchCatalog('musica');
      expect(noAccent.any((s) => s.title == 'De Música Ligera'), isTrue);

      // Searching "BESAME" in uppercase should find "Bésame Mucho"
      final uppercase = PreloadedSongsCatalog.searchCatalog('BESAME');
      expect(uppercase.any((s) => s.title == 'Bésame Mucho'), isTrue);
    });

    test('Empty or whitespace query returns all 20 songs', () {
      final emptyResult = PreloadedSongsCatalog.searchCatalog('');
      expect(emptyResult.length, equals(20));

      final whitespaceResult = PreloadedSongsCatalog.searchCatalog('    \t\n  ');
      expect(whitespaceResult.length, equals(20));
    });

    test('Boundary queries: special characters and nonexistent songs return empty gracefully', () {
      final specialResult = PreloadedSongsCatalog.searchCatalog('!@#\$%^&*()');
      expect(specialResult, isEmpty);

      final nonExistent = PreloadedSongsCatalog.searchCatalog('CancionInexistenteXYZ123');
      expect(nonExistent, isEmpty);
    });

    test('getSongById retrieves valid song or null if not found', () {
      final song = PreloadedSongsCatalog.getSongById('preloaded_de_musica_ligera');
      expect(song, isNotNull);
      expect(song!.title, equals('De Música Ligera'));

      final notFound = PreloadedSongsCatalog.getSongById('non_existent_id');
      expect(notFound, isNull);
    });
  });

  group('R5: SongSearchService Dual-Mode & Graceful Fallback', () {
    test('Default offline search returns catalog items as SearchResultSong', () async {
      final service = SongSearchService();
      final results = await service.search(query: 'Lamento Boliviano', offlineOnly: true);

      expect(results.length, equals(1));
      expect(results.first.title, equals('Lamento Boliviano'));
      expect(results.first.isOfflineCatalog, isTrue);
      expect(results.first.genre, equals('Rock en Español'));
    });

    test('Dual-mode search merges online results with offline catalog', () async {
      // Inject mock online fetcher for deterministic testing
      final service = SongSearchService(
        customOnlineFetcher: (q) async => [
          const SearchResultSong(
            id: 'online_1',
            title: 'Persiana Americana',
            artist: 'Soda Stereo',
            chordProContent: '[G]Yo te vi en un tren',
            isOfflineCatalog: false,
            genre: 'Rock',
          ),
        ],
      );

      final results = await service.search(query: 'Soda Stereo');
      expect(results.any((s) => s.title == 'De Música Ligera' && s.isOfflineCatalog), isTrue);
      expect(results.any((s) => s.title == 'Persiana Americana' && !s.isOfflineCatalog), isTrue);
    });

    test('Graceful fallback: when online search throws, offline catalog still succeeds', () async {
      final service = SongSearchService(
        customOnlineFetcher: (q) async => throw Exception('Network timeout / offline error'),
      );

      final results = await service.search(query: 'Stand by Me');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.title, equals('Stand by Me'));
      expect(results.first.isOfflineCatalog, isTrue);
    });

    test('Filtering by offlineOnly or onlineOnly works accurately', () async {
      final service = SongSearchService(
        customOnlineFetcher: (q) async => [
          const SearchResultSong(
            id: 'online_hit',
            title: 'Online Exclusive Hit',
            artist: 'Online Artist',
            chordProContent: 'Lyrics text',
            isOfflineCatalog: false,
          ),
        ],
      );

      final offlineOnly = await service.search(query: 'Hotel California', offlineOnly: true);
      expect(offlineOnly.every((s) => s.isOfflineCatalog), isTrue);

      final onlineOnly = await service.search(query: 'Exclusive', onlineOnly: true);
      expect(onlineOnly.every((s) => !s.isOfflineCatalog), isTrue);
    });
  });

  group('R5: SongPreviewSheet (Chord Alignment & 1-Tap Import)', () {
    testWidgets('Renders chords monospace amber directly above lyric syllables', (tester) async {
      final preloaded = PreloadedSongsCatalog.getSongById('preloaded_de_musica_ligera')!;
      final searchSong = SearchResultSong.fromPreloaded(preloaded);
      final songsService = SavedSongsService();
      SongScript? importedScript;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongPreviewSheet(
              song: searchSong,
              songsService: songsService,
              onSongImported: (script) => importedScript = script,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title and artist
      expect(find.text('De Música Ligera'), findsOneWidget);
      expect(find.text('Soda Stereo'), findsOneWidget);

      // Metadata badges
      expect(find.textContaining('Bm'), findsWidgets);
      expect(find.textContaining('125 BPM'), findsOneWidget);
      expect(find.textContaining('Offline'), findsWidgets);

      // Chords rendered in amber color
      final chordTexts = tester.widgetList<Text>(find.byWidgetPredicate((w) {
        if (w is Text && w.style?.color == AppColors.chordAmber && w.style?.fontFamily == 'monospace') {
          return true;
        }
        return false;
      }));
      expect(chordTexts.isNotEmpty, isTrue, reason: 'Chords must be rendered in amber monospace font');

      // Lyrics words rendered in white
      expect(find.text('Ella'), findsWidgets);
      expect(find.text('durmió'), findsWidgets);

      // Instrumental tag
      expect(find.textContaining('INTRO'), findsWidgets);

      // 1-tap import button exists
      final importButton = find.byKey(const Key('song_preview_import_button'));
      expect(importButton, findsOneWidget);

      // Tap import button
      await tester.tap(importButton);
      await tester.pumpAndSettle();

      expect(importedScript, isNotNull);
      expect(importedScript!.title, equals('De Música Ligera'));
    });
  });

  group('R5: SongSearchDialog (UI, Clear, Filter Chips, Selection)', () {
    testWidgets('Opens dialog, searches catalog, filters, and previews song', (tester) async {
      final songsService = SavedSongsService();
      SongScript? selectedSong;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SongSearchDialog.show(
                    context,
                    songsService: songsService,
                    onSongSelected: (song) => selectedSong = song,
                  );
                },
                child: const Text('Abrir Buscador'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to open search dialog
      await tester.tap(find.text('Abrir Buscador'));
      await tester.pumpAndSettle();

      // Verify search dialog elements
      expect(find.text('Buscar Letras y Acordes'), findsOneWidget);
      expect(find.byKey(const Key('song_search_text_field')), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Éxitos Populares (Offline)'), findsOneWidget);
      expect(find.text('En Línea'), findsOneWidget);

      // Initial list shows 20 preloaded songs
      expect(find.text('De Música Ligera'), findsOneWidget);

      // Type in search field
      await tester.enterText(find.byKey(const Key('song_search_text_field')), 'Bamba');
      await tester.pumpAndSettle();

      // Only La Bamba should match
      expect(find.text('La Bamba'), findsOneWidget);
      expect(find.text('De Música Ligera'), findsNothing);

      // Clear button should be visible
      final clearButton = find.byKey(const Key('song_search_clear_button'));
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // All songs restored
      expect(find.text('De Música Ligera'), findsOneWidget);

      // Tap on a song to preview
      await tester.tap(find.text('De Música Ligera'));
      await tester.pumpAndSettle();

      // SongPreviewSheet should now be mounted
      expect(find.byType(SongPreviewSheet), findsOneWidget);

      // Tap 1-tap import
      await tester.tap(find.byKey(const Key('song_preview_import_button')));
      await tester.pumpAndSettle();

      // Dialog and sheet dismissed, song selected
      expect(selectedSong, isNotNull);
      expect(selectedSong!.title, equals('De Música Ligera'));
    });
  });

  group('Integration in StudioRecordingScreen', () {
    testWidgets('Drawer menu contains "Buscar Letras y Acordes" and opens search dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StudioRecordingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open lateral menu
      final hamburger = find.byType(AnimatedIcon);
      expect(hamburger, findsOneWidget);
      await tester.tap(hamburger);
      await tester.pumpAndSettle();

      // Locate "Buscador de Canciones y Acordes"
      final searchMenuItem = find.text('Buscador de Canciones y Acordes');
      expect(searchMenuItem, findsOneWidget);

      // Tap search menu item
      await tester.tap(searchMenuItem);
      await tester.pumpAndSettle();

      // SongSearchDialog is now visible
      expect(find.byType(SongSearchDialog), findsOneWidget);
    });
  });
}
