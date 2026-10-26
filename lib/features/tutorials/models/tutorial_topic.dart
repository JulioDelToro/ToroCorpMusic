import 'package:flutter/material.dart';

/// Temas de tutoriales y guías contextuales para el usuario
enum TutorialTopic {
  palmGesture(
    title: 'Gesto de Palma (Manos Libres)',
    icon: Icons.front_hand,
    summary: 'Inicia la grabación sin soltar tu guitarra mostrando la palma abierta.',
    instructions: [
      'Colócate frente a la cámara a una distancia cómoda (0.5 a 2 metros).',
      'Levanta tu mano abierta mostrando la palma hacia el lente durante 1 segundo.',
      'La app detectará el gesto e iniciará una cuenta regresiva 3... 2... 1... ¡A grabar!',
      'Tendrás tiempo suficiente para acomodar tus dedos en el mástil.',
    ],
  ),
  voiceCommand(
    title: 'Comandos de Voz',
    icon: Icons.mic,
    summary: 'Di en voz alta la palabra clave para activar la cuenta regresiva.',
    instructions: [
      'Con la guitarra lista, di claramente: "Grabar" o "Iniciar".',
      'El motor de audio detectará la orden e iniciará la cuenta de 3 segundos.',
    ],
  ),
  vocalTracking(
    title: 'Seguimiento por Voz (Karaoke)',
    icon: Icons.record_voice_over,
    summary: 'La app te espera y pinta la letra conforme cantas cada palabra.',
    instructions: [
      'El teleprompter avanza al ritmo exacto en que cantas.',
      'Si te detienes a improvisar o hacer un solo de guitarra, el texto se detiene y te espera.',
      'El sonido de rasgueo de la guitarra es filtrado para no causar avances falsos.',
    ],
  ),
  tuner(
    title: 'Afinador de Guitarra Integrado',
    icon: Icons.tune,
    summary: 'Afina tus cuerdas antes de grabar sin salirte a otra aplicación.',
    instructions: [
      'Toca una cuerda al aire cerca del micrófono.',
      'La aguja indicará si la cuerda está baja (rojo/izquierda) o alta (amarillo/derecha).',
      'Cuando la aguja se ilumine en VERDE, tu cuerda está perfectamente afinada (±3.5¢).',
      'El afinador se apaga automáticamente al grabar para ahorrar batería.',
    ],
  ),
  chordDictionary(
    title: 'Diccionario de Acordes en el Diapasón',
    icon: Icons.menu_book,
    summary: 'Consulta la posición exacta de los dedos tocando cualquier acorde.',
    instructions: [
      'En el teleprompter, cada acorde aparece en la fila inferior de la palabra.',
      'Toca con tu dedo sobre cualquier nota o acorde para abrir el diagrama del mástil.',
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
    summary: 'Importa tus canciones favoritas en formato texto o PDF.',
    instructions: [
      'Puedes escribir o pegar texto con acordes en corchetes [G], [D] o [Em].',
      'Si cargas un PDF que contenga filas de acordes arriba de la letra, la app los detecta y los acomoda automáticamente debajo de cada palabra.',
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
