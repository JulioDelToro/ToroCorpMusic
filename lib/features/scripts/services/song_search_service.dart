import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/saved_song.dart';
import '../models/song_script.dart';
import 'chordpro_parser.dart';
import 'preloaded_songs_catalog.dart';

/// Modelo unificado para resultados de búsqueda de canciones (locales o en línea).
class SearchResultSong {
  final String id;
  final String title;
  final String artist;
  final String chordProContent;
  final bool isOfflineCatalog;
  final String genre;
  final String musicalKey;
  final int bpm;

  const SearchResultSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.chordProContent,
    this.isOfflineCatalog = true,
    this.genre = 'Popular',
    this.musicalKey = 'C',
    this.bpm = 120,
  });

  factory SearchResultSong.fromPreloaded(PreloadedSong song) {
    return SearchResultSong(
      id: song.id,
      title: song.title,
      artist: song.artist,
      chordProContent: song.chordProContent,
      isOfflineCatalog: true,
      genre: song.genre,
      musicalKey: song.musicalKey,
      bpm: song.bpm,
    );
  }

  /// Convierte el resultado directamente a un SongScript listo para teleprompter
  SongScript toSongScript() {
    return ChordProParser().parse(
      chordProContent,
      title: title,
      artist: artist,
    );
  }

  /// Convierte el resultado al formato de persistencia local SavedSong
  SavedSong toSavedSong() {
    return SavedSong(
      id: id,
      title: title,
      artist: artist,
      content: chordProContent,
      updatedAt: DateTime.now(),
    );
  }
}

/// Definición de función para inyección de búsquedas en línea (útil para pruebas unitarias)
typedef OnlineSearchFetcher = Future<List<SearchResultSong>> Function(String query);

/// Servicio de búsqueda dual para letras y acordes:
/// 1. Consulta instantánea en la biblioteca offline de 20 éxitos populares.
/// 2. Consulta a APIs públicas abiertas de letras con fallback silencioso y tolerante a fallos
///    en caso de falta de conexión o tiempos de espera agotados.
class SongSearchService {
  final OnlineSearchFetcher? customOnlineFetcher;
  final Duration networkTimeout;

  SongSearchService({
    this.customOnlineFetcher,
    this.networkTimeout = const Duration(milliseconds: 2500),
  });

  /// Realiza la búsqueda de canciones con soporte de filtros (Todos, Solo Offline, Solo En Línea)
  Future<List<SearchResultSong>> search({
    required String query,
    bool offlineOnly = false,
    bool onlineOnly = false,
  }) async {
    final cleanQuery = query.trim();

    // 1. Obtener canciones del catálogo preestablecido
    final catalogMatches = offlineOnly || !onlineOnly
        ? PreloadedSongsCatalog.searchCatalog(cleanQuery)
            .map((song) => SearchResultSong.fromPreloaded(song))
            .toList()
        : <SearchResultSong>[];

    if (offlineOnly || cleanQuery.isEmpty) {
      return catalogMatches;
    }

    // 2. Consulta en línea con fallback silencioso
    List<SearchResultSong> onlineMatches = [];
    try {
      final fetcher = customOnlineFetcher;
      if (fetcher != null) {
        onlineMatches = await fetcher(cleanQuery);
      } else {
        onlineMatches = await _queryPublicLyricsApi(cleanQuery);
      }
    } catch (e) {
      debugPrint('SongSearchService: Consulta en línea no disponible ($e). Usando fallback offline.');
      onlineMatches = [];
    }

    if (onlineOnly) {
      return onlineMatches;
    }

    // 3. Fusión y deduplicación: si una canción ya existe en el catálogo offline,
    // se prioriza la versión local con acordes verificados.
    final combined = <SearchResultSong>[...catalogMatches];
    final existingSignatures = catalogMatches
        .map((s) => '${s.title.toLowerCase()}::${s.artist.toLowerCase()}')
        .toSet();

    for (final onlineSong in onlineMatches) {
      final sig = '${onlineSong.title.toLowerCase()}::${onlineSong.artist.toLowerCase()}';
      if (!existingSignatures.contains(sig)) {
        combined.add(onlineSong);
        existingSignatures.add(sig);
      }
    }

    return combined;
  }

  /// Consulta el endpoint público de letras abiertas (LRCLIB u OpenAPI de letras)
  Future<List<SearchResultSong>> _queryPublicLyricsApi(String query) async {
    final client = HttpClient();
    client.connectionTimeout = networkTimeout;

    try {
      final uri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}');
      final request = await client.getUrl(uri).timeout(networkTimeout);
      final response = await request.close().timeout(networkTimeout);

      if (response.statusCode != HttpStatus.ok) {
        return [];
      }

      final body = await response.transform(utf8.decoder).join();
      final dynamic decoded = json.decode(body);

      if (decoded is! List) return [];

      final results = <SearchResultSong>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final trackName = item['trackName'] as String? ?? '';
          final artistName = item['artistName'] as String? ?? 'Desconocido';
          final plainLyrics = item['plainLyrics'] as String? ?? item['syncedLyrics'] as String? ?? '';

          if (trackName.isNotEmpty && plainLyrics.trim().isNotEmpty) {
            final songId = 'online_${item['id'] ?? DateTime.now().millisecondsSinceEpoch}';
            results.add(SearchResultSong(
              id: songId,
              title: trackName,
              artist: artistName,
              chordProContent: plainLyrics,
              isOfflineCatalog: false,
              genre: 'En Línea',
              musicalKey: 'C',
              bpm: 120,
            ));
          }
        }
      }
      return results;
    } catch (_) {
      // Cualquier fallo de red o parseo se degrada limpiamente
      return [];
    } finally {
      client.close();
    }
  }

  /// Parsea una cadena de texto o ChordPro en un SongScript estructurado
  SongScript parseChordPro(String rawText, {String title = 'Sin título', String artist = 'Desconocido'}) {
    return ChordProParser().parse(rawText, title: title, artist: artist);
  }
}
