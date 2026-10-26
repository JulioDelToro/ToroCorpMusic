import '../models/chord_definition.dart';

/// Base de datos local de acordes estándar para guitarra con soporte en cifrado americano y español.
class GuitarChordsDatabase {
  static final Map<String, ChordDefinition> _chords = {
    // Acordes Mayores
    'C': const ChordDefinition(name: 'C', frets: [-1, 3, 2, 0, 1, 0], fingers: [0, 3, 2, 0, 1, 0]),
    'D': const ChordDefinition(name: 'D', frets: [-1, -1, 0, 2, 3, 2], fingers: [0, 0, 0, 1, 3, 2]),
    'E': const ChordDefinition(name: 'E', frets: [0, 2, 2, 1, 0, 0], fingers: [0, 2, 3, 1, 0, 0]),
    'F': const ChordDefinition(name: 'F', frets: [1, 3, 3, 2, 1, 1], fingers: [1, 3, 4, 2, 1, 1]),
    'G': const ChordDefinition(name: 'G', frets: [3, 2, 0, 0, 0, 3], fingers: [2, 1, 0, 0, 0, 3]),
    'A': const ChordDefinition(name: 'A', frets: [-1, 0, 2, 2, 2, 0], fingers: [0, 0, 1, 2, 3, 0]),
    'B': const ChordDefinition(name: 'B', frets: [-1, 2, 4, 4, 4, 2], fingers: [0, 1, 2, 3, 4, 1], baseFret: 2),

    // Acordes Menores
    'Cm': const ChordDefinition(name: 'Cm', frets: [-1, 3, 5, 5, 4, 3], fingers: [0, 1, 3, 4, 2, 1], baseFret: 3),
    'Dm': const ChordDefinition(name: 'Dm', frets: [-1, -1, 0, 2, 3, 1], fingers: [0, 0, 0, 2, 3, 1]),
    'Em': const ChordDefinition(name: 'Em', frets: [0, 2, 2, 0, 0, 0], fingers: [0, 2, 3, 0, 0, 0]),
    'Fm': const ChordDefinition(name: 'Fm', frets: [1, 3, 3, 1, 1, 1], fingers: [1, 3, 4, 1, 1, 1]),
    'Gm': const ChordDefinition(name: 'Gm', frets: [3, 5, 5, 3, 3, 3], fingers: [1, 3, 4, 1, 1, 1], baseFret: 3),
    'Am': const ChordDefinition(name: 'Am', frets: [-1, 0, 2, 2, 1, 0], fingers: [0, 0, 2, 3, 1, 0]),
    'Bm': const ChordDefinition(name: 'Bm', frets: [-1, 2, 4, 4, 3, 2], fingers: [0, 1, 3, 4, 2, 1], baseFret: 2),

    // Acordes de Séptima
    'C7': const ChordDefinition(name: 'C7', frets: [-1, 3, 2, 3, 1, 0], fingers: [0, 3, 2, 4, 1, 0]),
    'D7': const ChordDefinition(name: 'D7', frets: [-1, -1, 0, 2, 1, 2], fingers: [0, 0, 0, 2, 1, 3]),
    'E7': const ChordDefinition(name: 'E7', frets: [0, 2, 0, 1, 0, 0], fingers: [0, 2, 0, 1, 0, 0]),
    'G7': const ChordDefinition(name: 'G7', frets: [3, 2, 0, 0, 0, 1], fingers: [3, 2, 0, 0, 0, 1]),
    'A7': const ChordDefinition(name: 'A7', frets: [-1, 0, 2, 0, 2, 0], fingers: [0, 0, 1, 0, 2, 0]),
    'B7': const ChordDefinition(name: 'B7', frets: [-1, 2, 1, 2, 0, 2], fingers: [0, 2, 1, 3, 0, 4]),
    'Em7': const ChordDefinition(name: 'Em7', frets: [0, 2, 0, 0, 0, 0], fingers: [0, 1, 0, 0, 0, 0]),
    'Am7': const ChordDefinition(name: 'Am7', frets: [-1, 0, 2, 0, 1, 0], fingers: [0, 0, 2, 0, 1, 0]),
  };

  static final Map<String, String> _spanishAliases = {
    'DO': 'C',
    'RE': 'D',
    'MI': 'E',
    'FA': 'F',
    'SOL': 'G',
    'LA': 'A',
    'SI': 'B',
    'DOM': 'Cm',
    'REM': 'Dm',
    'MIM': 'Em',
    'FAM': 'Fm',
    'SOLM': 'Gm',
    'LAM': 'Am',
    'SIM': 'Bm',
    'DO7': 'C7',
    'RE7': 'D7',
    'MI7': 'E7',
    'FA7': 'F7',
    'SOL7': 'G7',
    'LA7': 'A7',
    'SI7': 'B7',
  };

  ChordDefinition? getChord(String rawName) {
    final clean = rawName.trim().replaceAll(RegExp(r'[\[\]]'), '');
    if (_chords.containsKey(clean)) {
      return _chords[clean];
    }

    // Probar mayúsculas
    final upper = clean.toUpperCase();
    if (_chords.containsKey(upper)) {
      return _chords[upper];
    }

    // Probar alias en español
    if (_spanishAliases.containsKey(upper)) {
      final englishName = _spanishAliases[upper]!;
      return _chords[englishName];
    }

    return null;
  }
}
