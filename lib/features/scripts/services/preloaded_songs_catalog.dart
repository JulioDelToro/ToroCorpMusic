import '../models/saved_song.dart';
import '../models/song_script.dart';
import 'chordpro_parser.dart';

/// Modelo para una canción precargada en la biblioteca offline de ToroCorp Music.
class PreloadedSong {
  final String id;
  final String title;
  final String artist;
  final String genre;
  final String chordProContent;
  final String musicalKey;
  final int bpm;
  final bool isOfflineCatalog;

  const PreloadedSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.chordProContent,
    this.musicalKey = 'C',
    this.bpm = 120,
    this.isOfflineCatalog = true,
  });

  /// Convierte la canción a un SongScript listo para teleprompter
  SongScript toSongScript() {
    return ChordProParser().parse(
      chordProContent,
      title: title,
      artist: artist,
    );
  }

  /// Convierte la canción al modelo persistente SavedSong
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

/// Catálogo de 20 éxitos populares icónicos (en español, latinoamericanos e internacionales)
/// con acordes precisos en formato estándar ChordPro [Acorde].
/// 100% disponible offline para ensayos, afinación y presentaciones en vivo.
class PreloadedSongsCatalog {
  static const List<PreloadedSong> songs = [
    // 1. De Música Ligera - Soda Stereo
    PreloadedSong(
      id: 'preloaded_de_musica_ligera',
      title: 'De Música Ligera',
      artist: 'Soda Stereo',
      genre: 'Rock en Español',
      musicalKey: 'Bm',
      bpm: 125,
      chordProContent: '''
{title: De Música Ligera}
{artist: Soda Stereo}
{key: Bm}
{tempo: 125}

[🎸 INTRO]
[Bm] [G] [D] [A]

[Bm]Ella durmió al calor de las [G]masas
[D]Y yo desperté que[A]riendo soñarla
[Bm]No guardes algo si no te hace [G]falta
[D]No vendas sombras en [A]el jardín

[Bm]De aquel a[G]mor de [D]música li[A]gera
[Bm]Nada nos [G]libra, [D]nada más [A]queda

[Bm]No le enviaré las cenizas de [G]rosas
[D]Ni pienso evitar un [A]roce secreto
[Bm]De aquel a[G]mor de [D]música li[A]gera
[Bm]Nada nos [G]libra, [D]nada más [A]queda

[🎸 SOLO DE GUITARRA]
[Bm] [G] [D] [A]

[Bm]Nada más [G]queda, [D]nada más [A]queda
''',
    ),

    // 2. La Bamba - Los Lobos
    PreloadedSong(
      id: 'preloaded_la_bamba',
      title: 'La Bamba',
      artist: 'Los Lobos / Ritchie Valens',
      genre: 'Son Jarocho / Rock',
      musicalKey: 'C',
      bpm: 150,
      chordProContent: '''
{title: La Bamba}
{artist: Los Lobos}
{key: C}
{tempo: 150}

[🎸 REQUINTO]
[C] [F] [G]

[C]Para bailar la [F]bamba [G]
[C]Para bailar la [F]bamba se nece[G]sita
[C]Una poca de [F]gracia [G]
[C]Una poca de [F]gracia pa' mí, pa' [G]ti, ay arriba y a[C]rriba
[C]Ay arriba y a[F]rriba por ti se[G]ré
[C]Por ti se[F]ré, por [G]ti seré

[C]Yo no soy mari[F]nero [G]
[C]Yo no soy mari[F]nero, soy capi[G]tán
[C]Soy capi[F]tán, soy [G]capitán
[C]Bamba, [F]bamba, [G]bamba
''',
    ),

    // 3. Cielito Lindo - Tradicional Mexicano
    PreloadedSong(
      id: 'preloaded_cielito_lindo',
      title: 'Cielito Lindo',
      artist: 'Tradicional Mexicano',
      genre: 'Mariachi / Tradicional',
      musicalKey: 'C',
      bpm: 100,
      chordProContent: '''
{title: Cielito Lindo}
{artist: Tradicional Mexicano}
{key: C}
{tempo: 100}

[C]De la Sierra Morena, cielito lindo, vienen ba[G7]jando
[G7]Un par de ojitos negros, cielito lindo, de contra[C]bando

[C]Ay, ay, ay, [F]ay, [G7]canta y no [C]llores
[C]Porque cantando se [G7]alegran, cielito lindo, los cora[C]zones

[C]Ese lunar que tienes, cielito lindo, junto a la [G7]boca
[G7]No se lo des a nadie, cielito lindo, que a mí me [C]toca

[C]Ay, ay, ay, [F]ay, [G7]canta y no [C]llores
[C]Porque cantando se [G7]alegran, cielito lindo, los cora[C]zones
''',
    ),

    // 4. Guantanamera - Joseíto Fernández
    PreloadedSong(
      id: 'preloaded_guantanamera',
      title: 'Guantanamera',
      artist: 'Joseíto Fernández',
      genre: 'Son Cubano',
      musicalKey: 'G',
      bpm: 95,
      chordProContent: '''
{title: Guantanamera}
{artist: Joseíto Fernández}
{key: G}
{tempo: 95}

[G]Guantanamera, [C]guajira [D]guantanamera
[G]Guantana[C]mera, guajira [D]guantanamera

[G]Yo soy un [C]hombre sincero [D]
[G]De donde [C]crece la palma [D]
[G]Y antes de mo[C]rirme quiero [D]
[G]Cantar mis [C]versos del alma [D]

[G]Guantanamera, [C]guajira [D]guantanamera
[G]Guantana[C]mera, guajira [D]guantanamera
''',
    ),

    // 5. Bésame Mucho - Consuelo Velázquez
    PreloadedSong(
      id: 'preloaded_besame_mucho',
      title: 'Bésame Mucho',
      artist: 'Consuelo Velázquez',
      genre: 'Bolero',
      musicalKey: 'Dm',
      bpm: 85,
      chordProContent: '''
{title: Bésame Mucho}
{artist: Consuelo Velázquez}
{key: Dm}
{tempo: 85}

[Dm]Bésame, [Gm]bésame [Dm]mucho
[Gm]Como si fuera esta [Dm]noche la [A7]última vez
[Gm]Bésame, [Dm]bésame mucho
[E7]Que tengo miedo a perderte, perderte des[A7]pués

[Gm]Quiero tenerte muy [Dm]cerca
[A7]Mirarme en tus ojos, verte junto a [Dm]mí
[Gm]Piensa que tal vez ma[Dm]ñana
[E7]Yo ya estaré lejos, muy lejos de [A7]aquí

[Dm]Bésame, [Gm]bésame [Dm]mucho
[Gm]Como si fuera esta [Dm]noche la [A7]última vez
''',
    ),

    // 6. Amor Eterno - Juan Gabriel
    PreloadedSong(
      id: 'preloaded_amor_eterno',
      title: 'Amor Eterno',
      artist: 'Juan Gabriel',
      genre: 'Ranchera / Balada',
      musicalKey: 'G',
      bpm: 80,
      chordProContent: '''
{title: Amor Eterno}
{artist: Juan Gabriel}
{key: G}
{tempo: 80}

[G]Tú eres la tristeza de mis [Am]ojos
[D7]Que lloran en silencio por tu a[G]mor
[G]Me miro en el espejo y veo en mi [Am]rostro
[D7]El tiempo que he sufrido por tu a[G]diós

[G7]Obligo a que te olvide el pensa[C]miento
[D7]Pues siempre estoy pensando en el a[G]yer
[Em]Prefiero estar dormido que des[Am]pierto
[D7]De tanto que me duele que no es[G]tés

[G7]Cómo quisiera [C]que tú vivieras [G]
[Am]Que tus ojitos jamás se hubieran [D7]cerrado nunca
[D7]Y estar mirán[G]dolos
[G7]Amor e[C]terno e inolvidable [G]
[Am]Tarde o temprano estaré con[D7]tigo para seguir amán[G]donos
''',
    ),

    // 7. Rayando el Sol - Maná
    PreloadedSong(
      id: 'preloaded_rayando_el_sol',
      title: 'Rayando el Sol',
      artist: 'Maná',
      genre: 'Pop Rock',
      musicalKey: 'G',
      bpm: 90,
      chordProContent: '''
{title: Rayando el Sol}
{artist: Maná}
{key: G}
{tempo: 90}

[🎸 INTRO]
[G] [D] [Em] [C]

[G]Rayando el sol, [D]rayando por ti
[Em]Esta pena me duele con [C]frenesí
[G]A mi casa me voy a [D]quedar
[Em]Esperando a que vuelvas a [C]entrar

[G]Rayando el sol, desespe[D]ración
[Em]Es más fácil llegar al sol que a tu [C]corazón
[G]Me muero por ti, vi[D]viendo sin ti
[Em]Y no aguanto, me duele tanto es[C]tar así

[G]Rayando el [D]sol, oh [Em]oh [C]
[G]Rayando el [D]sol [Em] [C]
''',
    ),

    // 8. Oye Cómo Va - Santana / Tito Puente
    PreloadedSong(
      id: 'preloaded_oye_como_va',
      title: 'Oye Cómo Va',
      artist: 'Santana / Tito Puente',
      genre: 'Latin Rock',
      musicalKey: 'Am',
      bpm: 130,
      chordProContent: '''
{title: Oye Cómo Va}
{artist: Santana}
{key: Am}
{tempo: 130}

[🎸 INTRO]
[Am7] [D7] [Am7] [D7]

[Am7]Oye cómo [D7]va, mi [Am7]ritmo [D7]
[Am7]Bueno pa' go[D7]zar, mu[Am7]lata [D7]
[Am7]Oye cómo [D7]va, mi [Am7]ritmo [D7]
[Am7]Bueno pa' go[D7]zar, mu[Am7]lata [D7]

[🎸 SOLO DE GUITARRA]
[Am7] [D7] [Am7] [D7]
[Am7] [D7] [Am7] [D7]
''',
    ),

    // 9. Lamento Boliviano - Los Enanitos Verdes
    PreloadedSong(
      id: 'preloaded_lamento_boliviano',
      title: 'Lamento Boliviano',
      artist: 'Los Enanitos Verdes',
      genre: 'Rock en Español',
      musicalKey: 'Em',
      bpm: 120,
      chordProContent: '''
{title: Lamento Boliviano}
{artist: Los Enanitos Verdes}
{key: Em}
{tempo: 120}

[🎸 INTRO]
[Em] [Bm] [Am] [Em] [B7]

[Em]Me quieren agitar, me [Bm]incitan a gritar
[Am]Soy como una roca, palabras no me [Em]tocan [B7]
[Em]Adentro hay un volcán que [Bm]pronto va a estallar
[Am]Yo quiero estar tranquilo [B7]

[Em]Es una situación muy [Bm]difícil de llevar
[Am]Siento que en cualquier momento voy a re[Em]ventar [B7]
[Em]Y mi corazón idiota [Bm]siempre brillará
[Am]Y yo te amaré, te ama[B7]ré por siempre

[Em]Nena, no te [Bm]pongas así
[Am]Que todo va a estar bien [B7]
''',
    ),

    // 10. Stand by Me - Ben E. King
    PreloadedSong(
      id: 'preloaded_stand_by_me',
      title: 'Stand by Me',
      artist: 'Ben E. King',
      genre: 'Soul / Classic',
      musicalKey: 'A',
      bpm: 118,
      chordProContent: '''
{title: Stand by Me}
{artist: Ben E. King}
{key: A}
{tempo: 118}

[A]When the night has come and the [F#m]land is dark
[D]And the moon is the [E]only light we'll [A]see
[A]No I won't be afraid, no I [F#m]won't be afraid
[D]Just as long as you [E]stand, stand by [A]me

[A]So darling, darling stand by me, oh [F#m]stand by me
[D]Oh stand, [E]stand by me, [A]stand by me

[A]If the sky that we look upon should [F#m]tumble and fall
[D]Or the mountain should [E]crumble to the [A]sea
[A]I won't cry, I won't cry, no I [F#m]won't shed a tear
[D]Just as long as you [E]stand, stand by [A]me
''',
    ),

    // 11. Hotel California - Eagles
    PreloadedSong(
      id: 'preloaded_hotel_california',
      title: 'Hotel California',
      artist: 'Eagles',
      genre: 'Classic Rock',
      musicalKey: 'Bm',
      bpm: 75,
      chordProContent: '''
{title: Hotel California}
{artist: Eagles}
{key: Bm}
{tempo: 75}

[🎸 INTRO 12-STRING]
[Bm] [F#] [A] [E] [G] [D] [Em] [F#]

[Bm]On a dark desert highway, [F#]cool wind in my hair
[A]Warm smell of colitas, [E]rising up through the air
[G]Up ahead in the distance, [D]I saw a shimmering light
[Em]My head grew heavy and my sight grew dim, [F#]I had to stop for the night

[G]Welcome to the Hotel Cali[D]fornia
[F#]Such a lovely place, such a [Bm]lovely face
[G]Plenty of room at the Hotel Cali[D]fornia
[Em]Any time of year, you can [F#]find it here
''',
    ),

    // 12. Let It Be - The Beatles
    PreloadedSong(
      id: 'preloaded_let_it_be',
      title: 'Let It Be',
      artist: 'The Beatles',
      genre: 'Classic Rock / Pop',
      musicalKey: 'C',
      bpm: 72,
      chordProContent: '''
{title: Let It Be}
{artist: The Beatles}
{key: C}
{tempo: 72}

[C]When I find myself in [G]times of trouble, [Am]Mother Mary [F]comes to me
[C]Speaking words of [G]wisdom, let it [F]be [C]
[C]And in my hour of [G]darkness she is [Am]standing right in [F]front of me
[C]Speaking words of [G]wisdom, let it [F]be [C]

[Am]Let it be, [G]let it be, [F]let it be, [C]let it be
[C]Whisper words of [G]wisdom, let it [F]be [C]

[C]And when the broken hearted [G]people living [Am]in the world a[F]gree
[C]There will be an [G]answer, let it [F]be [C]
''',
    ),

    // 13. Yesterday - The Beatles
    PreloadedSong(
      id: 'preloaded_yesterday',
      title: 'Yesterday',
      artist: 'The Beatles',
      genre: 'Acoustic / Pop',
      musicalKey: 'F',
      bpm: 96,
      chordProContent: '''
{title: Yesterday}
{artist: The Beatles}
{key: F}
{tempo: 96}

[F]Yesterday, [Em7]all my troubles [A7]seemed so far a[Dm]way [C]
[Bb]Now it looks as [C]though they're here to [F]stay
[Dm]Oh, I be[G7]lieve in [Bb]yester[F]day

[F]Suddenly, [Em7]I'm not half the [A7]man I used to [Dm]be [C]
[Bb]There's a shadow [C]hanging over [F]me
[Dm]Oh, yester[G7]day came [Bb]sudden[F]ly

[A7]Why she [Dm]had [C]to [Bb]go I don't [C]know, she wouldn't [F]say
[A7]I said [Dm]some[C]thing [Bb]wrong, now I [C]long for yester[F]day
''',
    ),

    // 14. Knockin' on Heaven's Door - Bob Dylan
    PreloadedSong(
      id: 'preloaded_knockin_on_heavens_door',
      title: "Knockin' on Heaven's Door",
      artist: 'Bob Dylan',
      genre: 'Folk Rock',
      musicalKey: 'G',
      bpm: 70,
      chordProContent: '''
{title: Knockin' on Heaven's Door}
{artist: Bob Dylan}
{key: G}
{tempo: 70}

[G]Mama, take this [D]badge off of [Am]me
[G]I can't [D]use it any[C]more
[G]It's gettin' dark, too [D]dark to [Am]see
[G]I feel I'm [D]knockin' on heaven's [C]door

[G]Knock, knock, [D]knockin' on heaven's [Am]door
[G]Knock, knock, [D]knockin' on heaven's [C]door
[G]Knock, knock, [D]knockin' on heaven's [Am]door
[G]Knock, knock, [D]knockin' on heaven's [C]door

[G]Mama, put my [D]guns in the [Am]ground
[G]I can't [D]shoot them any[C]more
''',
    ),

    // 15. El Rey - José Alfredo Jiménez
    PreloadedSong(
      id: 'preloaded_el_rey',
      title: 'El Rey',
      artist: 'José Alfredo Jiménez',
      genre: 'Ranchera / Mariachi',
      musicalKey: 'G',
      bpm: 110,
      chordProContent: '''
{title: El Rey}
{artist: José Alfredo Jiménez}
{key: G}
{tempo: 110}

[G]Yo sé bien que estoy afuera, [D7]pero el día que yo me muera
[D7]Sé que tendrás que llorar, [G]llorar y llorar
[G]Dirás que no me quisiste, [D7]pero vas a estar muy triste
[D7]Y así te me vas a quedar [G]

[C]Con dinero y sin dinero, [G]hago siempre lo que quiero
[D7]Y mi palabra es la [G]ley
[C]No tengo trono ni reina, [G]ni nadie que me comprenda
[D7]Pero sigo siendo el [G]rey

[G]Una piedra en el camino [D7]me enseñó que mi destino
[D7]Era rodar y rodar, [G]rodar y rodar
''',
    ),

    // 16. Volver Volver - Vicente Fernández
    PreloadedSong(
      id: 'preloaded_volver_volver',
      title: 'Volver Volver',
      artist: 'Vicente Fernández',
      genre: 'Ranchera',
      musicalKey: 'D',
      bpm: 80,
      chordProContent: '''
{title: Volver Volver}
{artist: Vicente Fernández}
{key: D}
{tempo: 80}

[D]Este amor apasionado, anda [A7]todo alborotado por volver
[A7]Voy camino a la locura y aunque todo me tortura, [D]sé querer
[D]Nos dejamos hace tiempo, pero [D7]llega el momento de a[G]clarar

[G]Y volver, volver, [D]volver a tus brazos [A7]otra vez
[A7]Llegaré hasta donde estés, yo sé perder, [D]yo sé perder, quiero volver
[G]Volver, volver, [D]volver a tus brazos [A7]otra vez
[A7]Llegaré hasta donde estés, yo sé perder, [D]yo sé perder, quiero volver
''',
    ),

    // 17. Color Esperanza - Diego Torres
    PreloadedSong(
      id: 'preloaded_color_esperanza',
      title: 'Color Esperanza',
      artist: 'Diego Torres',
      genre: 'Pop Latino',
      musicalKey: 'G',
      bpm: 115,
      chordProContent: '''
{title: Color Esperanza}
{artist: Diego Torres}
{key: G}
{tempo: 115}

[G]Sé que hay en tus [D]ojos con solo mirar
[Em]Que estás cansado de [Bm]andar y de andar
[C]Y caminar, gi[G]rando siempre en un [Am]lugar [D]

[G]Sé que las ven[D]tanas se pueden abrir
[Em]Cambiar el aire de[Bm]pende de ti
[C]Te ayudará, [G]vale la pena una [Am]vez más [D]

[C]Saber que se [D]puede, querer que se [G]pueda
[C]Quitarse los [D]miedos, sacarlos a[Em]fuera
[C]Pintarse la [D]cara color espe[G]ranza
[C]Tentar al fu[D]turo con el cora[G]zón
''',
    ),

    // 18. Mi Gente - J Balvin & Willy William
    PreloadedSong(
      id: 'preloaded_mi_gente',
      title: 'Mi Gente',
      artist: 'J Balvin & Willy William',
      genre: 'Reggaeton / Urbano',
      musicalKey: 'F#m',
      bpm: 105,
      chordProContent: '''
{title: Mi Gente}
{artist: J Balvin}
{key: F#m}
{tempo: 105}

[F#m]Si el ritmo te lleva a mover la cabeza
[D]Ya empezamos como es
[Bm]Mi música no discrimina a nadie
[C#m]Así que vamos a romper

[F#m]Toda mi gente se mueve
[D]Mira el ritmo cómo los tiene
[Bm]Hago música que entretiene
[C#m]Mi música los tiene fuerte bailando

[F#m]Y se queda con mi gente
[D]Se fue mundial, no podemos parar
[Bm]Es una fiesta que nunca va a acabar
[C#m]Así que vamos a romper
''',
    ),

    // 19. Despacito - Luis Fonsi ft. Daddy Yankee
    PreloadedSong(
      id: 'preloaded_despacito',
      title: 'Despacito',
      artist: 'Luis Fonsi ft. Daddy Yankee',
      genre: 'Pop Latino / Reggaeton',
      musicalKey: 'Bm',
      bpm: 89,
      chordProContent: '''
{title: Despacito}
{artist: Luis Fonsi}
{key: Bm}
{tempo: 89}

[Bm]Sí, sabes que ya llevo un rato mi[G]rándote
[D]Tengo que bailar contigo [A]hoy
[Bm]Vi que tu mirada ya estaba lla[G]mándome
[D]Muéstrame el camino que yo [A]voy

[Bm]Tú, tú eres el imán y yo soy el me[G]tal
[G]Me voy acercando y voy armando el [D]plan
[D]Sólo con pensarlo se acelera el [A]pulso

[Bm]Des-pa-ci-to [G]
[G]Quiero respirar tu cuello despa[D]cito
[D]Deja que te diga cosas al o[A]ído
[A]Para que te acuerdes si no estás con[Bm]migo
[Bm]Des-pa-ci-to [G]
''',
    ),

    // 20. Eres - Café Tacvba
    PreloadedSong(
      id: 'preloaded_eres',
      title: 'Eres',
      artist: 'Café Tacvba',
      genre: 'Rock Alternativo',
      musicalKey: 'E',
      bpm: 80,
      chordProContent: '''
{title: Eres}
{artist: Café Tacvba}
{key: E}
{tempo: 80}

[E]Eres lo que más quiero en este [B]mundo eso eres
[C#m]Mi pensamiento más profundo [A]eres
[E]Tan sólo dime lo que pasa a[B]quí, aquí
[C#m]Que cuando estoy junto a ti, las [A]horas pasan así

[F#m]Y yo quiero decirte que te [B]quiero
[F#m]Y yo quiero cantarte que no [B]puedo vivir sin ti

[E]Eres lo que más quiero en este [B]mundo eso eres
[C#m]La luz que alumbra toda mi exis[A]tencia eres
[E]No hay nada más que desear en [B]esta vida
[C#m]Que compartir mis días [A]junto a ti
''',
    ),
  ];

  /// Normaliza una cadena de texto para búsqueda insensible a mayúsculas y acentos
  static String _normalize(String input) {
    var text = input.toLowerCase();
    text = text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
    return text;
  }

  /// Busca canciones dentro del catálogo preestablecido por título, artista o fragmento de letra.
  /// Si [query] está vacío o solo contiene espacios en blanco, devuelve la lista completa de 20 canciones.
  static List<PreloadedSong> searchCatalog(String query) {
    final clean = query.trim();
    if (clean.isEmpty) {
      return List.unmodifiable(songs);
    }

    final normalizedQuery = _normalize(clean);

    return songs.where((song) {
      final normTitle = _normalize(song.title);
      final normArtist = _normalize(song.artist);
      final normGenre = _normalize(song.genre);
      final normLyrics = _normalize(song.chordProContent);
      final cleanLyrics = normLyrics.replaceAll(RegExp(r'\[.*?\]'), '');

      return normTitle.contains(normalizedQuery) ||
          normArtist.contains(normalizedQuery) ||
          normGenre.contains(normalizedQuery) ||
          normLyrics.contains(normalizedQuery) ||
          cleanLyrics.contains(normalizedQuery);
    }).toList();
  }

  /// Obtiene una canción específica por su identificador único
  static PreloadedSong? getSongById(String id) {
    try {
      return songs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
