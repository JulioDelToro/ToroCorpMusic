import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/saved_song.dart';

/// Servicio de persistencia local para la sección "Letras" (guardado de canciones y guiones).
/// 100% comercial y privado, guardado en el almacenamiento local del dispositivo.
class SavedSongsService {
  static const String _fileName = 'toro_saved_lyrics.json';
  List<SavedSong>? _cachedSongs;

  Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('ToroCorp Music: Info path_provider: $e');
      return null;
    }
  }

  /// Carga todas las canciones guardadas
  Future<List<SavedSong>> loadSongs() async {
    if (_cachedSongs != null) return List.unmodifiable(_cachedSongs!);

    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = json.decode(content);
          _cachedSongs = list.map((item) => SavedSong.fromMap(item as Map<String, dynamic>)).toList();
          return List.unmodifiable(_cachedSongs!);
        }
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Error cargando canciones guardadas: $e');
    }

    _cachedSongs ??= [];
    return List.unmodifiable(_cachedSongs!);
  }

  /// Guarda una canción (nueva o actualizada)
  Future<SavedSong> saveSong({
    String? id,
    required String title,
    required String content,
  }) async {
    final songs = (await loadSongs()).toList();
    final songId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final newSong = SavedSong(
      id: songId,
      title: title.trim().isEmpty ? 'Canción sin título' : title.trim(),
      content: content.trim(),
      updatedAt: DateTime.now(),
    );

    final existingIndex = songs.indexWhere((s) => s.id == songId);
    if (existingIndex >= 0) {
      songs[existingIndex] = newSong;
    } else {
      songs.insert(0, newSong);
    }

    _cachedSongs = songs;
    await _persist();
    return newSong;
  }

  /// Elimina una canción por ID
  Future<void> deleteSong(String id) async {
    final songs = (await loadSongs()).toList();
    songs.removeWhere((s) => s.id == id);
    _cachedSongs = songs;
    await _persist();
  }

  Future<void> _persist() async {
    if (_cachedSongs == null) return;
    try {
      final file = await _getFile();
      if (file != null) {
        final raw = json.encode(_cachedSongs!.map((s) => s.toMap()).toList());
        await file.writeAsString(raw);
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Error guardando letras: $e');
    }
  }
}
