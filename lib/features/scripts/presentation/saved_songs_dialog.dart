import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../models/saved_song.dart';
import '../models/song_script.dart';
import '../services/saved_songs_service.dart';
import 'song_search_dialog.dart';

/// Diálogo modal para la sección "Letras" (Biblioteca de Repertorio y Creación de Guiones).
class SavedSongsDialog extends StatefulWidget {
  final SavedSongsService songsService;
  final ValueChanged<SongScript> onSongSelected;
  final VoidCallback onClearSong;
  final bool hasActiveSong;

  const SavedSongsDialog({
    super.key,
    required this.songsService,
    required this.onSongSelected,
    required this.onClearSong,
    this.hasActiveSong = false,
  });

  static Future<void> show(
    BuildContext context, {
    required SavedSongsService songsService,
    required ValueChanged<SongScript> onSongSelected,
    required VoidCallback onClearSong,
    bool hasActiveSong = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.pureBlackOled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SavedSongsDialog(
        songsService: songsService,
        onSongSelected: onSongSelected,
        onClearSong: onClearSong,
        hasActiveSong: hasActiveSong,
      ),
    );
  }

  @override
  State<SavedSongsDialog> createState() => _SavedSongsDialogState();
}

class _SavedSongsDialogState extends State<SavedSongsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();

  List<SavedSong> _savedSongs = [];
  bool _isLoading = true;
  String? _editingSongId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    final list = await widget.songsService.loadSongs();
    if (mounted) {
      setState(() {
        _savedSongs = list;
        _isLoading = false;
        // Si no hay canciones guardadas, mostrar pestaña de escribir/pegar
        if (_savedSongs.isEmpty) {
          _tabController.index = 1;
        }
      });
    }
  }

  void _applyAndClose(SongScript script) {
    widget.onSongSelected(script);
    Navigator.of(context).pop();
  }

  Future<void> _saveAndApply() async {
    final title = _titleController.text.trim();
    final content = _lyricsController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe o pega la letra de la canción.'),
          backgroundColor: AppColors.cardDark,
        ),
      );
      return;
    }

    final finalTitle = title.isEmpty ? 'Canción ${DateTime.now().minute}' : title;

    final saved = await widget.songsService.saveSong(
      id: _editingSongId,
      title: finalTitle,
      content: content,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡"$finalTitle" guardada en Letras!'),
          backgroundColor: AppColors.surfaceDark,
        ),
      );
      _applyAndClose(saved.toSongScript());
    }
  }

  void _applyWithoutSaving() {
    final title = _titleController.text.trim();
    final content = _lyricsController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe o pega la letra de la canción.'),
          backgroundColor: AppColors.cardDark,
        ),
      );
      return;
    }

    final temp = SavedSong(
      id: 'temp',
      title: title.isEmpty ? 'Canción temporal' : title,
      content: content,
      updatedAt: DateTime.now(),
    );

    _applyAndClose(temp.toSongScript());
  }

  void _editSong(SavedSong song) {
    setState(() {
      _editingSongId = song.id;
      _titleController.text = song.title;
      _lyricsController.text = song.content;
      _tabController.index = 1;
    });
  }

  Future<void> _deleteSong(String id) async {
    await widget.songsService.deleteSong(id);
    await _loadSongs();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Cabecera
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.lyrics, color: AppColors.chordAmber, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Letras y Repertorio',
                    style: AppTypography.sfProHeadline(fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Pestañas
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.chordAmber,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Guardadas (${_savedSongs.length})'),
                const Tab(text: 'Escribir / Pegar'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── PESTAÑA 1: Canciones Guardadas ────────────────────────────
                _buildSavedListTab(),

                // ── PESTAÑA 2: Escribir o Pegar ──────────────────────────────
                _buildWriteOrPasteTab(),
              ],
            ),
          ),

          // Botón inferior para limpiar teleprompter si hay canción activa
          if (widget.hasActiveSong)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton.icon(
                onPressed: () {
                  widget.onClearSong();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_sweep, color: AppColors.recordRed, size: 18),
                label: const Text(
                  'Limpiar Teleprompter (Dejar Vacío)',
                  style: TextStyle(color: AppColors.recordRed, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.chordAmber));
    }

    if (_savedSongs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.library_music_outlined, color: Colors.white24, size: 54),
              const SizedBox(height: 12),
              const Text(
                'No tienes canciones guardadas aún.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('saved_songs_search_button_empty'),
                onPressed: () {
                  SongSearchDialog.show(
                    context,
                    songsService: widget.songsService,
                    onSongSelected: _applyAndClose,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chordAmber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(240, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.search, color: Colors.black),
                label: const Text(
                  'Buscar en Catálogo / En Línea',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.chordAmber,
                  side: const BorderSide(color: AppColors.chordAmber),
                  minimumSize: const Size(240, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Escribir o Pegar Letra'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: ElevatedButton.icon(
            key: const Key('saved_songs_search_button'),
            onPressed: () {
              SongSearchDialog.show(
                context,
                songsService: widget.songsService,
                onSongSelected: _applyAndClose,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardDark,
              foregroundColor: AppColors.chordAmber,
              side: const BorderSide(color: AppColors.chordAmber, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(42),
            ),
            icon: const Icon(Icons.search, color: AppColors.chordAmber, size: 20),
            label: const Text(
              'Buscar en Línea / Catálogo de 20 Éxitos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _savedSongs.length,
            itemBuilder: (context, index) {
              final song = _savedSongs[index];
              final preview = song.content.split('\n').take(2).join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceDark,
              child: Icon(Icons.music_note, color: AppColors.chordAmber, size: 20),
            ),
            title: Text(
              song.title,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              preview.isEmpty ? 'Letra vacía' : preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white60, size: 18),
                  onPressed: () => _editSong(song),
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () => _deleteSong(song.id),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
            onTap: () => _applyAndClose(song.toSongScript()),
          ),
        );
      },
    ),
  ),
],
);
  }

  Widget _buildWriteOrPasteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo de Título
          TextField(
            controller: _titleController,
            style: const TextStyle(color: AppColors.textWhite, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Título de la Canción',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintText: 'Ej: De Música Ligera, Mi Canción 1...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: AppColors.cardDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.chordAmber, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Campo de Letra Multilínea
          TextField(
            controller: _lyricsController,
            maxLines: 8,
            style: const TextStyle(color: AppColors.textWhite, fontSize: 14, height: 1.3),
            decoration: InputDecoration(
              labelText: 'Letra de la Canción',
              alignLabelWithHint: true,
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintText: 'Pega o escribe aquí la letra de tu canción...\n\nPuedes incluir acordes entre corchetes, ej:\n[Bm] De aquel amor\n[G] De música ligera',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: AppColors.cardDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.chordAmber, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _applyWithoutSaving,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textWhite,
                    side: const BorderSide(color: AppColors.borderDark),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cargar sin Guardar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveAndApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.chordAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.bookmark_add, size: 20),
                  label: Text(_editingSongId != null ? 'Actualizar' : 'Guardar y Usar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
