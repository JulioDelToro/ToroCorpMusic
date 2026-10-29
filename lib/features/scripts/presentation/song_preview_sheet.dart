import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/song_script.dart';
import '../services/saved_songs_service.dart';
import '../services/song_search_service.dart';

/// Hoja modal de previsualización de canción con acordes alineados directamente sobre las sílabas.
/// Incluye botón de importación de 1 solo toque que guarda la canción en la biblioteca local
/// y la monta directamente en el teleprompter de la Isla Dinámica.
class SongPreviewSheet extends StatelessWidget {
  final SearchResultSong song;
  final SavedSongsService songsService;
  final ValueChanged<SongScript> onSongImported;

  const SongPreviewSheet({
    super.key,
    required this.song,
    required this.songsService,
    required this.onSongImported,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SearchResultSong song,
    required SavedSongsService songsService,
    required ValueChanged<SongScript> onSongImported,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pureBlackOled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SongPreviewSheet(
        song: song,
        songsService: songsService,
        onSongImported: onSongImported,
      ),
    );
  }

  Future<void> _importSong(BuildContext context) async {
    final songScript = song.toSongScript();

    // 1. Invocar callback para montar de inmediato en la Isla Dinámica
    onSongImported(songScript);

    // 2. Guardar en almacenamiento local persistente
    try {
      await songsService.saveSong(
        id: song.id,
        title: song.title,
        content: song.chordProContent,
      );
    } catch (e) {
      debugPrint('SongPreviewSheet: Error guardando canción: $e');
    }

    // 3. Cerrar la hoja de previsualización
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songScript = song.toSongScript();
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.pureBlackOled,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de arrastre superior
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Encabezado de la canción
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: AppTypography.sfProHeadline(
                          fontSize: 20,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: AppTypography.sfProBody(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Fila de metadatos (Tonalidad, BPM, Género, Origen)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildBadge(
                            icon: Icons.music_note,
                            label: 'Tonalidad: ${song.musicalKey}',
                            color: AppColors.chordAmber,
                          ),
                          _buildBadge(
                            icon: Icons.speed,
                            label: '${song.bpm} BPM',
                            color: Colors.white70,
                          ),
                          _buildBadge(
                            icon: Icons.category_outlined,
                            label: song.genre,
                            color: Colors.white70,
                          ),
                          _buildBadge(
                            icon: song.isOfflineCatalog ? Icons.offline_pin : Icons.cloud_outlined,
                            label: song.isOfflineCatalog ? 'Offline' : 'En Línea',
                            color: song.isOfflineCatalog ? AppColors.tunerInTuneGreen : Colors.lightBlueAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.borderDark, height: 1),

          // Cuerpo de la letra con acordes alineados directamente sobre las sílabas
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: songScript.lines.length,
              itemBuilder: (context, lineIndex) {
                final line = songScript.lines[lineIndex];

                // Sección instrumental (Requinto / Solo / Intro)
                if (line.isInstrumental) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.chordAmber.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.chordAmber.withAlpha(120), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note, color: AppColors.chordAmber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          line.instrumentalLabel ?? '🎸 SECCIÓN INSTRUMENTAL',
                          style: const TextStyle(
                            color: AppColors.chordAmber,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Línea normal con acordes monospace color ámbar arriba y letra abajo
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: line.tokens.map((token) {
                      final hasChord = token.chordUnderneath != null && token.chordUnderneath!.isNotEmpty;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Acorde monospace en ámbar dorado
                          Text(
                            hasChord ? token.chordUnderneath! : '',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.chordAmber,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Sílaba o palabra de la letra
                          Text(
                            token.word,
                            style: AppTypography.sfProLyricStyle(
                              fontSize: 15,
                              color: AppColors.textWhite,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // Botón inferior de 1 toque para importar a biblioteca y montar en teleprompter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.cardDark,
              border: Border(top: BorderSide(color: AppColors.borderDark, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                key: const Key('song_preview_import_button'),
                onPressed: () => _importSong(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chordAmber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.file_download, color: Colors.black, size: 22),
                label: const Text(
                  'Importar y Montar en Teleprompter',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
