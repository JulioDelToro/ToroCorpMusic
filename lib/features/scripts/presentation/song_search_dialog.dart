import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/song_script.dart';
import '../services/saved_songs_service.dart';
import '../services/song_search_service.dart';
import 'song_preview_sheet.dart';

enum SearchFilterMode {
  all(label: 'Todos'),
  offline(label: 'Éxitos Populares (Offline)'),
  online(label: 'En Línea');

  final String label;
  const SearchFilterMode({required this.label});
}

/// Diálogo modal interactivo para búsqueda rápida de letras y acordes
/// (catálogo offline de 20 éxitos populares y búsqueda pública en línea con fallback seguro).
class SongSearchDialog extends StatefulWidget {
  final SavedSongsService songsService;
  final ValueChanged<SongScript> onSongSelected;
  final SongSearchService? searchService;

  const SongSearchDialog({
    super.key,
    required this.songsService,
    required this.onSongSelected,
    this.searchService,
  });

  static Future<void> show(
    BuildContext context, {
    required SavedSongsService songsService,
    required ValueChanged<SongScript> onSongSelected,
    SongSearchService? searchService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pureBlackOled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SongSearchDialog(
        songsService: songsService,
        onSongSelected: onSongSelected,
        searchService: searchService,
      ),
    );
  }

  @override
  State<SongSearchDialog> createState() => _SongSearchDialogState();
}

class _SongSearchDialogState extends State<SongSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final SongSearchService _searchService;

  SearchFilterMode _activeFilter = SearchFilterMode.all;
  List<SearchResultSong> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ?? SongSearchService();
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    final query = _searchController.text;
    final results = await _searchService.search(
      query: query,
      offlineOnly: _activeFilter == SearchFilterMode.offline,
      onlineOnly: _activeFilter == SearchFilterMode.online,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _performSearch();
  }

  Future<void> _openSongPreview(SearchResultSong song) async {
    final imported = await SongPreviewSheet.show(
      context,
      song: song,
      songsService: widget.songsService,
      onSongImported: (script) {
        widget.onSongSelected(script);
      },
    );

    // Si la canción fue importada, cerramos también el diálogo de búsqueda
    if (imported == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.only(bottom: bottomInset),
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

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.chordAmber, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buscar Letras y Acordes',
                        style: AppTypography.sfProHeadline(fontSize: 18),
                      ),
                      Text(
                        '20 éxitos populares offline y búsqueda en línea',
                        style: AppTypography.sfProCaption(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Campo de texto de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              key: const Key('song_search_text_field'),
              controller: _searchController,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                hintText: 'Buscar canción, artista o letra...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.chordAmber),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        key: const Key('song_search_clear_button'),
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardDark,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.chordAmber, width: 1.5),
                ),
              ),
              onChanged: (_) => _performSearch(),
              onSubmitted: (_) => _performSearch(),
            ),
          ),

          // Chips de filtro (Todos, Éxitos Populares (Offline), En Línea)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: SearchFilterMode.values.map((filter) {
                final isSelected = filter == _activeFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _activeFilter = filter);
                        _performSearch();
                      }
                    },
                    backgroundColor: AppColors.cardDark,
                    selectedColor: AppColors.chordAmber.withAlpha(50),
                    checkmarkColor: AppColors.chordAmber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.chordAmber : AppColors.borderDark,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.chordAmber : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(color: AppColors.borderDark, height: 1),

          // Resultados de la búsqueda
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.chordAmber))
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, color: Colors.white24, size: 52),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? 'No hay canciones disponibles'
                                  : 'No se encontraron canciones para "${_searchController.text.trim()}"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Prueba buscando por otro título, artista o fragmento de letra.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final song = _results[index];
                          return InkWell(
                            onTap: () => _openSongPreview(song),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.borderDark, width: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: song.isOfflineCatalog
                                          ? AppColors.chordAmber.withAlpha(30)
                                          : Colors.blueAccent.withAlpha(30),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: song.isOfflineCatalog
                                            ? AppColors.chordAmber.withAlpha(90)
                                            : Colors.blueAccent.withAlpha(90),
                                      ),
                                    ),
                                    child: Icon(
                                      song.isOfflineCatalog ? Icons.music_note : Icons.cloud_outlined,
                                      color: song.isOfflineCatalog ? AppColors.chordAmber : Colors.lightBlueAccent,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: AppTypography.sfProHeadline(
                                            fontSize: 15,
                                            color: AppColors.textWhite,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${song.artist} • ${song.genre}',
                                          style: AppTypography.sfProCaption(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: song.isOfflineCatalog
                                          ? AppColors.tunerInTuneGreen.withAlpha(25)
                                          : Colors.blueAccent.withAlpha(25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: song.isOfflineCatalog
                                            ? AppColors.tunerInTuneGreen.withAlpha(80)
                                            : Colors.blueAccent.withAlpha(80),
                                      ),
                                    ),
                                    child: Text(
                                      song.isOfflineCatalog ? 'Offline' : 'En Línea',
                                      style: TextStyle(
                                        color: song.isOfflineCatalog
                                            ? AppColors.tunerInTuneGreen
                                            : Colors.lightBlueAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
