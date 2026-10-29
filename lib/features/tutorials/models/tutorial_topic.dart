import 'package:flutter/material.dart';

/// Temas de tutoriales y guías contextuales didácticas para el usuario
enum TutorialTopic {
  cameraAndDynamicIsland(
    title: 'Modo Ensayo / Atril y Cámara a Demanda',
    icon: Icons.fit_screen,
    summary: 'La app inicia con cámara apagada en Negro OLED para ensayar o grabar a voluntad.',
    instructions: [
      'Inicio Inteligente: La app inicia siempre con la cámara apagada para proteger tu batería y ensayar cómodamente en Negro Puro OLED.',
      'Atril a Pantalla Completa: Con la cámara apagada, toca la cápsula de la Isla Dinámica para expandirla a pantalla completa y ver de 6 a 10 líneas de letra con acordes grandes.',
      'Cámara a Demanda: Cuando desees grabar video, enciende la cámara en cualquier momento activando el interruptor "Cámara (Video)" en el menú lateral.',
      'Retorno Fluido: Al encender la cámara, la Isla Dinámica regresa automáticamente a su cápsula compacta superior bajo el lente para mantener contacto visual.',
    ],
  ),
  palmGesture(
    title: 'Gesto de Palma (5s Manos Libres)',
    icon: Icons.front_hand,
    summary: 'Inicia la grabación sin soltar tu instrumento mostrando la palma abierta.',
    instructions: [
      'Colócate frente a la cámara a una distancia cómoda (0.5 a 2 metros).',
      'Levanta tu mano abierta mostrando la palma hacia el lente durante 1 segundo.',
      'La app detectará el gesto e iniciará la cuenta regresiva: 5 → 4 → 3 → 2 → 1 → ¡A grabar!',
      'Dispones de 5 segundos completos para acomodar tus dedos en el mástil y prepararte para tocar.',
    ],
  ),
  voiceCommand(
    title: 'Comandos de Voz (5s Manos Libres)',
    icon: Icons.mic,
    summary: 'Di en voz alta la palabra clave para activar la cuenta regresiva de 5 segundos.',
    instructions: [
      'Con tu guitarra en posición, di claramente: "Grabar" o "Iniciar".',
      'El motor de audio detectará la orden e iniciará la cuenta regresiva de 5 segundos (5 → 4 → 3 → 2 → 1).',
      'Tendrás tiempo de sobra para ubicar el primer acorde sin prisas.',
    ],
  ),
  metronome(
    title: 'Metrónomo Interactivo y Visual',
    icon: Icons.av_timer,
    summary: 'Marca el tempo exacto con pulsos visuales y clicks acústicos ultra-ligeros.',
    instructions: [
      'Abre el Metrónomo directamente desde el menú lateral, ubicado junto al Afinador.',
      'Ajusta el tempo entre 40 y 240 BPM mediante el deslizador continuo o los botones de ajuste fino (+/- 1 BPM).',
      'Usa el botón "Tap Tempo" pulsándolo al compás de tu música para calcular los BPM de forma automática.',
      'Elige compases estándar (2/4, 3/4, 4/4, 6/8) con acentuación diferenciada en el tiempo 1 y destello visual sincrónico.',
    ],
  ),
  lyricsAndChordsSearch(
    title: 'Buscador de Letras y Acordes',
    icon: Icons.travel_explore,
    summary: 'Encuentra canciones en línea o explora la biblioteca offline y móntalas con 1 toque.',
    instructions: [
      'Abre "Letras y Repertorio" desde el menú lateral o toca el centro de la cápsula del teleprompter.',
      'Escribe el nombre de la canción o del artista en el buscador para consultar fuentes públicas abiertas en línea.',
      'Disfruta de la biblioteca precargada offline con éxitos populares para tocar de inmediato sin conexión a internet.',
      'Visualiza los acordes alineados sobre las sílabas exactas y presiona "Importar" para guardarla y montarla al instante.',
    ],
  ),
  tuner(
    title: 'Afinador de Guitarra (6 y 12 Cuerdas)',
    icon: Icons.tune,
    summary: 'Afina guitarra estándar de 6 cuerdas o docerola de 12 cuerdas con precisión profesional.',
    instructions: [
      'Selecciona el tipo de instrumento: guitarra estándar de 6 cuerdas o docerola / requinto de 12 cuerdas.',
      'Toca una cuerda al aire cerca del micrófono; el detector identificará la frecuencia y la nota en tiempo real.',
      'Observa la aguja y la indicación: si está baja verás "APRETAR" (ámbar), si está alta "AFLOJAR" (rojo).',
      'Cuando la cuerda esté afinada (±3.5¢), la pantalla se iluminará en VERDE con confirmación acústica.',
      'Puedes usar detección automática o fijar una cuerda pulsando su clavija en pantalla.',
    ],
  ),
  vocalTracking(
    title: 'Seguimiento por Voz (Karaoke)',
    icon: Icons.record_voice_over,
    summary: 'La app te escucha y resalta la letra conforme cantas cada palabra.',
    instructions: [
      'El teleprompter avanza al ritmo exacto en que cantas cada verso.',
      'Si te detienes a improvisar, hacer un solo de guitarra o requinto, el texto se detiene y te espera.',
      'El filtrado paso banda elimina los rasgueos de la guitarra para no causar avances falsos.',
    ],
  ),
  chordDictionary(
    title: 'Diccionario de Acordes en el Diapasón',
    icon: Icons.menu_book,
    summary: 'Consulta la posición exacta de los dedos tocando cualquier acorde.',
    instructions: [
      'En el teleprompter, cada acorde aparece en la fila superior de la palabra.',
      'Toca sobre cualquier acorde para abrir su diagrama interactivo del mástil.',
      'Verás los números de dedos recomendados y qué cuerdas pulsar o mutear.',
    ],
  ),
  beautyFilter(
    title: 'Filtro de Belleza Facial (GPU)',
    icon: Icons.auto_fix_high,
    summary: 'Ajusta la intensidad de suavizado de piel en tiempo real.',
    instructions: [
      'Desliza el control lateral entre 0% (natural) y 100% (glamour).',
      'El algoritmo inteligente suaviza imperfecciones de la piel pero preserva la nitidez de tus ojos y las cuerdas de tu guitarra.',
    ],
  ),
  pdfImport(
    title: 'Carga de Guiones y PDFs',
    icon: Icons.picture_as_pdf,
    summary: 'Importa tus canciones favoritas en formato texto o documento PDF.',
    instructions: [
      'Puedes escribir o pegar texto con acordes en corchetes [G], [D] o [Em].',
      'Si cargas un PDF que contenga filas de acordes arriba de la letra, la app los detecta y los vincula automáticamente a cada palabra.',
    ],
  );

  final String title;
  final IconData icon;
  final String summary;
  final List<String> instructions;

  const TutorialTopic({
    required this.title,
    required this.icon,
    required this.summary,
    required this.instructions,
  });
}
