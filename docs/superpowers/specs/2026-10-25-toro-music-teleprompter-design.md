# Especificación de Diseño: Toro Music Teleprompter & Video Studio

**Fecha**: 2026-10-25  
**Estado**: Aprobado por el usuario  
**Plataformas**: Android, iOS, Windows, macOS (Flutter Nativo)  
**Tema Visual**: Negro Puro OLED (`#000000`), Blanco (`#FFFFFF`) y Acentos de Contraste  

---

## 1. Visión del Producto y Propósito

**Toro Music Teleprompter** es una aplicación multiplataforma de grabación de video asistida por teleprompter inteligente y herramientas musicales, diseñada específicamente para cantantes, guitarristas y creadores de contenido musical. 

### Problema que resuelve
Al tocar guitarra y cantar frente a la cámara, los músicos comúnmente olvidan la letra o pierden el contacto visual al mirar hacia abajo a hojas de papel, atriles o pantallas lejanas. Además, los teleprompters tradicionales avanzan a una velocidad fija o se confunden con el sonido de la guitarra, y no ofrecen facilidades de afinación, visualización de acordes ni inicio de grabación sin soltar el instrumento.

### Solución integral
Una aplicación que:
1. Posiciona el teleprompter inmediatamente pegado al lente de la cámara para mantener contacto visual natural e imperceptible.
2. Sigue activamente la voz cantada mediante inteligencia artificial local (estilo karaoke), avanzando solo cuando el usuario pronuncia cada palabra y pausándose si el músico se detiene o improvisa.
3. Coloca las notas y acordes musicales en una fila de apoyo visual **justo debajo de la letra**.
4. Integra herramientas esenciales para guitarristas (afinador visual de guitarra y diccionario de acordes con diagramas de digitación).
5. Permite iniciar la grabación con las manos ocupadas mediante **gestos de la palma de la mano** o **comandos de voz**.
6. Aplica un **filtro de belleza facial** ajustable por GPU en tiempo real.
7. Ofrece un modelo de negocio freemium legalmente blindado con anuncios inteligentes, exportación limpia o con subtítulos, y suscripción prémium accesible para desbloquear 4K y eliminar marcas de agua.

---

## 2. Marco Legal, Propiedad Intelectual y Licenciamiento Comercial

Para garantizar que el software se pueda vender y monetizar bajo suscripción sin ningún riesgo de demandas, infracciones de patentes o reclamos de copyright:

1. **Framework y Lenguaje**:
   * **Flutter & Dart**: Licencia **BSD 3-Clause** (Google). 100% legal y gratuito para software propietario con fines de lucro.
2. **Códificación de Video**:
   * **Codificadores de Hardware Nativos**: Uso exclusivo de los códecs provistos por los sistemas operativos (`MediaCodec` en Android, `AVFoundation / VideoToolbox` en iOS/macOS, `MediaFoundation` en Windows) a través del plugin oficial de Flutter `camera`.
   * **Cero riesgo de FFmpeg GPL**: Se descarta el uso de binarios de FFmpeg bajo GPL, evitando exigencias de liberación de código fuente o demandas por regalías de H.264/AAC.
3. **Visión por Computadora y Detección de Gestos**:
   * **Google MediaPipe Hands / ML Kit**: Licencia **Apache 2.0**. Libre de regalías y autorizado para aplicaciones comerciales cerradas.
4. **Reconocimiento de Voz On-Device**:
   * **Vosk / Kaldi / Whisper GGML**: Licencias **Apache 2.0** y **MIT**. Procesamiento local en el dispositivo sin costos de servidores ni fuga de datos privados de audio.
5. **Lectura de PDFs**:
   * **pdfx / pdf_text**: Licencia **MIT**. Se prohíbe el uso de librerías bajo licencias AGPL (como MuPDF) para salvaguardar la propiedad del código cerrado.
6. **Pasarelas de Pago e In-App Purchases**:
   * Utilización del estándar `in_app_purchase` de Flutter para procesamiento directo con Google Play Billing y Apple StoreKit (comisión del 15% bajo el programa para pequeños desarrolladores).

---

## 3. Identidad Visual y Experiencia de Usuario (UI/UX)

### 3.1 Estética OLED Black
* **Fondo General**: Negro Puro (`#000000`). En pantallas OLED/AMOLED (teléfonos modernos) apaga los píxeles, logrando un contraste infinito, aspecto cinematográfico y ahorro significativo de batería durante grabaciones prolongadas.
* **Tipografía (Ecosistema iOS / Apple Design)**:
  * **Familia Tipográfica Principal**: **SF Pro Display / SF Pro Text** (la tipografía oficial del ecosistema de iOS/Apple), garantizando máxima legibilidad, elegancia minimalista y estética prémium.
  * **Letras cantadas (Teleprompter)**: SF Pro en Blanco puro (`#FFFFFF`), peso tipográfico `Bold` / `Heavy` (w700-w800), escalable de 18sp a 36sp con tracking óptico ajustado para lectura cómoda a distancia.
  * **Notas / Acordes (Fila inferior)**: **SF Mono** (versión monoespaciada de Apple) en acento Ámbar Cálido (`#FFD166`) o Blanco Ceniza (`#CCCCCC`), garantizando que cada nota quede milimétricamente alineada debajo de la sílaba correspondiente.
  * **Resaltado de Karaoke**: Resplandor dinámico (*glow*) y transición de color a medida que la palabra se canta.
* **Bordes y Superficies**: Gris oscuro (`#1E1E1E` y `#2A2A2A`).

### 3.2 Pantalla de Inicio (Splash Screen en Video)
* **Archivo de Video**: `App_splash_screen_intro_1080p_20261025201354.mp4` (ubicado en la raíz del proyecto).
* **Comportamiento**:
  * Reproducción automática a pantalla completa al abrir la aplicación.
  * Decodificación acelerada por hardware.
  * Transición fluida con desvanecimiento (fade-out) al terminar hacia el menú principal.
  * Gesto de toque o clic en cualquier parte de la pantalla para omitir el video de inmediato si el usuario desea grabar con rapidez.

---

## 4. Módulos y Arquitectura del Sistema

```
┌────────────────────────────────────────────────────────────────────────┐
│                        INTERFAZ DE USUARIO (UI)                        │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │  Teleprompter Flotante (Bajo el Lente de la Cámara)          │     │
│   │  [Fila Letra]  "De   música   ligera..."  (resaltado voz)    │     │
│   │  [Fila Notas]   Sol            Re         (apoyo visual)     │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
│   ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │
│   │ Afinador Guitarra│  │ Diccionario Acord│  │ Slider Filtro 0-100│   │
│   └──────────────────┘  └──────────────────┘  └────────────────────┘   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │  Visor Cámara + Disparador Manos Libres (Palma / Voz "Grabar") │   │
│   └────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          ▼                         ▼                         ▼
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  Camera & Shader │      │  Audio & Voice   │      │ Document & Chords│
│     Pipeline     │      │ Alignment Engine │      │     Manager      │
│                  │      │                  │      │                  │
│ • Preview Stream │      │ • Mic Capture    │      │ • PDF text & note│
│ • GLSL Beauty FX │      │ • Guitar Filter  │      │   extractor      │
│ • Palm Detection │      │ • Vocal Matcher  │      │ • ChordPro parser│
│ • Clean vs Burned│      │ • Word Index Pub │      │ • Chord diagrams │
└─────────┬────────┘      └────────┬─────────┘      └────────┬─────────┘
          │                        │                         │
          └────────────────────────┼─────────────────────────┘
                                   ▼
                    ┌──────────────────────────────┐
                    │ Video Recording Compositor   │
                    │ • H.264 Video + AAC Audio    │
                    │ • 720p / 1080p / 4K Options  │
                    │ • Watermark Overlay System   │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │ Monetization & Ad Subsystem  │
                    │ • Interstitial on Save       │
                    │ • Rewarded Ad (4K/No-Water)  │
                    │ • In-App Purchase (Pro Sub)  │
                    └──────────────────────────────┘
```

---

## 5. Especificaciones Detalladas por Subsistema

### 5.1 Teleprompter y Formato de Letra con Notas Inferiores
* **Ubicación en Pantalla**: El contenedor del teleprompter se ancla a los primeros 120-180 píxeles superiores de la pantalla (justo debajo del notch o del orificio de la cámara en smartphones, o en el borde superior centrado en PC) para que el ángulo de visión de los ojos coincida con el lente.
* **Estructura Bidireccional de Cada Bloque**:
  * **Elemento Superior**: Palabra o frase de la letra cantada.
  * **Elemento Inferior**: Nota musical o acorde correspondiente fijado exactamente debajo de la sílaba en la que debe sonar.
* **Alineación Visual**: Si un verso no tiene notas en ciertas palabras, el espacio inferior se conserva limpio para no desfasar el ritmo visual.

### 5.2 Motor de Inteligencia Artificial para Seguimiento de Voz (Karaoke Tracking)
* **Aislamiento de Voz vs. Guitarra**:
  * Se aplica un filtro de paso de banda (band-pass filter) centrado en las frecuencias vocales humanas (100 Hz a 3.4 kHz) y una puerta de ruido (*noise gate*) que atenúa el rasgueo brillante de las cuerdas agudas de la guitarra.
* **Seguimiento Fonético / Lexical**:
  * El motor de voz compara el flujo de texto reconocido con la lista de palabras del guion actual.
  * **Comportamiento en Pausa**: Si el usuario deja de cantar para hacer un solo de guitarra o una introducción instrumental, el teleprompter no avanza a ciegas; permanece quieto en la última palabra cantada.
  * **Efecto Karaoke**: La palabra activa cambia de estilo (resplandor luminoso y color blanco radiante), y la vista se desplaza suavemente hacia arriba manteniendo siempre visible la línea actual y la siguiente.
* **Respaldo Manual / Automático**:
  * Si hay condiciones extremas de ruido o guitarra eléctrica amplificada, el usuario puede activar con un botón el avance automático a velocidad regulable (BPM) o tocar la pantalla para avanzar estrofas.

### 5.3 Cámara, Filtro de Belleza y Grabación
* **Filtro de Belleza GLSL en Tiempo Real**:
  * Algoritmo de suavizado bilateral en fragment shader que calcula diferencias de color en el espacio de piel, filtrando poros e imperfecciones cutáneas mientras mantiene intacta la nitidez de ojos, cejas, labios y cuerdas de la guitarra.
  * **Control Deslizante (0% a 100%)**:
    * `0%`: Sin filtro (sensor nativo puro).
    * `1% - 50%`: Suavizado natural sutil.
    * `51% - 100%`: Filtro de belleza estilizado de alta intensidad.
* **Inicio de Grabación Manos Libres**:
  * **Gesto de Palma**: Detección de la mano abierta con los 5 dedos extendidos mirando hacia la cámara frontal durante 1 segundo consecutivo.
  * **Comando de Voz**: Detección de la palabra clave *"Grabar"* o *"Iniciar"* en el micrófono.
  * **Cuenta Regresiva**: Al activarse cualquiera de los dos métodos, se despliega una animación visual en pantalla grande: `3... 2... 1... ¡A grabar!` acompañada de beeps sutiles, dando tiempo al guitarrista de acomodar sus manos en el mástil.
* **Modos de Salida de Video**:
  * **Modo A (Video Limpio)**: Exporta el archivo MP4 capturando únicamente la imagen de la cámara con el filtro de belleza y el audio del micrófono.
  * **Modo B (Video con Guion Incrustado)**: Exporta el archivo MP4 combinando en el canvas de codificación el video de la cámara junto con la barra de letra, notas y el resaltado activo de karaoke.

### 5.4 Herramientas para Músicos
1. **Afinador de Guitarra Integrado**:
   * Algoritmo de detección de tono por autocorrelación / YIN sobre la señal de audio.
   * Detección automática de cuerda para afinación estándar (`E2, A2, D3, G3, B3, E4`).
   * Visualizador con aguja indicadora de afinación (marca verde cuando está afinada $\pm 3$ cents).
   * Se silencia o desactiva automáticamente al iniciar la grabación para no consumir ciclos de CPU.
2. **Diccionario Interactivo de Acordes**:
   * Base de datos local integrada de acordes mayores, menores, séptimas, suspendidos y disminuidos.
   * Al hacer tap/clic sobre cualquier nota o acorde en el teleprompter, se abre un diálogo modal flotante con el diagrama del mástil de guitarra mostrando trastes, cuerdas y números de dedos.

### 5.5 Gestión de Guiones y Carga de PDFs
* **Editor Directo**: Área de texto que soporta el estándar musical `ChordPro`, por ejemplo:
  ```
  De [G]música [D]ligera...
  Nada nos [Em]libra, nada más [C]queda...
  ```
* **Importador de PDFs**:
  * Extracción de capas de texto de archivos PDF de letras o partituras.
  * Parser automático que identifica líneas de acordes (por ejemplo, líneas con palabras compuestas de `C, D, Em, F#, G7`) y las asocia directamente como notas en la fila inferior de la letra correspondiente.

---

## 6. Modelo de Negocio y Monetización

```
┌──────────────────────────────────────────────┐
│                  NIVELES                     │
├──────────────────────┬───────────────────────┤
│    NIVEL GRATUITO    │     NIVEL PRO         │
│                      │  (Micro-Suscripción)  │
├──────────────────────┼───────────────────────┤
│ • Teleprompter Total │ • Sin Marca de Agua   │
│ • Afinador y Acordes │ • 4K a 30 fps         │
│ • Filtro de Belleza  │ • 4K a 60 fps         │
│ • 720p y 1080p       │ • CERO Publicidad     │
│ • Marca de Agua      │ • Soporte Prioritario │
│ • Anuncio al guardar │                       │
└──────────────────────┴───────────────────────┘
```

* **Flujo de Anuncios**:
  * **Anuncio Intersticial**: Se carga y muestra en la versión gratuita al terminar de grabar, en el instante en que el usuario presiona "Guardar en Galería" o "Exportar", sin interferir jamás con la toma de video en vivo.
  * **Anuncio Recompensado (Rewarded Video)**: Antes de exportar, se ofrece un botón con la opción: *"¿Deseas exportar este video en 4K o sin marca de agua gratis por esta vez? Mira un anuncio de 20 segundos"*. Al completarse el anuncio, se le otorga el pase único para ese video.
  * **Suscripción Pro**: Desactiva todos los anuncios, quita la marca de agua permanentemente y habilita resoluciones 4K@30 y 4K@60fps.

---

## 7. Módulo de Tutoriales y Ayuda Contextual

Cada sección clave de la aplicación cuenta con un icono de información `(?)` y un sistema de asistencia:
1. **Tutorial de Palma**: Demostración animada con ilustración de cómo mostrar la palma de la mano a la distancia adecuada frente al lente.
2. **Tutorial de Teleprompter**: Guía sobre cómo colocar el dispositivo a la altura de los ojos para que la lectura sea completamente indetectable.
3. **Tutorial de Afinación**: Explicación de la aguja y frecuencias de cuerdas.
4. **Tutorial de Carga de PDFs**: Muestra de cómo estructurar o cargar un PDF con acordes para que el sistema los ubique en la fila inferior.

---

## 8. Verificación y Plan de Calidad

* **Pruebas de Latencia de Audio**: El retardo del motor de reconocimiento vocal sobre la pista de audio debe ser menor a 80 ms para que el efecto visual de karaoke se sienta instantáneo.
* **Rendimiento de Cámara y Shaders**: Mantener una tasa constante de 60 fotogramas por segundo (o 30 fps en dispositivos de entrada) con el shader de belleza activo sin saltos de cuadro.
* **Prueba de Aislamiento Acústico**: Simular rasgueo enérgico de guitarra acústica y verificar que no dispare palabras falsas en el teleprompter.
* **Integridad de Exportación**: Verificar que el modo limpio exporte video sin artefactos ni textos quemados, y que el modo con guion incruste el texto con tipografía nítida y perfectamente sincronizada.
