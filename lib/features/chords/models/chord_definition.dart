/// Definición de digitación de un acorde para guitarra de 6 cuerdas.
class ChordDefinition {
  final String name;
  /// Traste para cada cuerda (índice 0 = 6ta cuerda E grave, índice 5 = 1ra cuerda E aguda).
  /// -1 indica cuerda muteada (X), 0 indica cuerda al aire (O), 1+ indica número de traste.
  final List<int> frets;
  /// Dedo asignado a cada cuerda (0 = ninguno, 1 = índice, 2 = medio, 3 = anular, 4 = meñique).
  final List<int> fingers;
  /// Traste base donde comienza el diagrama (1 por defecto).
  final int baseFret;

  const ChordDefinition({
    required this.name,
    required this.frets,
    required this.fingers,
    this.baseFret = 1,
  });

  @override
  String toString() => 'ChordDefinition(name: $name, frets: $frets, baseFret: $baseFret)';
}
