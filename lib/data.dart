import 'models.dart';

// Edita estas listas para cambiar el contenido de la app.

const forYou = [
  Collection('Hits del momento', 'Lista', 'hits del momento música'),
  Collection('Tus favoritos de siempre', 'Lista', 'éxitos de siempre en español'),
  Collection('Reggaeton', 'Lista', 'reggaeton éxitos'),
  Collection('Pop en español', 'Lista', 'pop español éxitos'),
];

const featured = [
  Collection('Éxitos del momento', 'Selección', 'éxitos del momento'),
  Collection('Lo mejor de los 2000', 'Selección', 'éxitos años 2000'),
  Collection('Flamenco', 'Selección', 'flamenco mix'),
  Collection('Rock en español', 'Selección', 'rock en español clásicos'),
];

const stations = [
  Collection('Pop', 'Emisora', 'pop mix', 0xFFD81B60),
  Collection('Reggaeton', 'Emisora', 'reggaeton mix', 0xFF8E24AA),
  Collection('Rock', 'Emisora', 'rock mix', 0xFFE64A19),
  Collection('Hip-Hop', 'Emisora', 'hip hop mix', 0xFF3949AB),
  Collection('Flamenco', 'Emisora', 'flamenco mix', 0xFFF9A825),
  Collection('Electrónica', 'Emisora', 'electronic mix', 0xFF00897B),
];

const mixes = [
  Collection('Lofi para estudiar', 'Mix', 'lofi hip hop mix'),
  Collection('Entrenar', 'Mix', 'gym workout music mix'),
  Collection('Chill', 'Mix', 'chill vibes mix'),
  Collection('Fiesta', 'Mix', 'fiesta latino mix'),
];

const genres = [
  Collection('Pop', 'Género', 'pop éxitos'),
  Collection('Rock', 'Género', 'rock éxitos'),
  Collection('Hip-Hop', 'Género', 'hip hop éxitos'),
  Collection('Reggaeton', 'Género', 'reggaeton éxitos'),
  Collection('Flamenco', 'Género', 'flamenco éxitos'),
  Collection('Electrónica', 'Género', 'electronic éxitos'),
  Collection('Latino', 'Género', 'música latina éxitos'),
  Collection('Jazz', 'Género', 'jazz clásicos'),
  Collection('Clásica', 'Género', 'música clásica'),
  Collection('Indie', 'Género', 'indie éxitos'),
];

const trending = [
  'bad bunny',
  'karol g',
  'quevedo',
  'rosalía',
  'c. tangana',
  'taylor swift',
];

class FeatureCard {
  final String kicker;
  final String title;
  final String subtitle;
  final String caption;
  final String query;
  const FeatureCard(this.kicker, this.title, this.subtitle, this.caption, this.query);
}

// Tarjetas grandes de Explorar (como "Novedades" de Apple Music).
const featureCards = [
  FeatureCard('LISTA ACTUALIZADA', 'CALLE', 'Urbano latino',
      'Los temas que marcan el pulso de la escena urbana ahora mismo.',
      'urbano latino nuevas canciones official audio'),
  FeatureCard('LO NUEVO', 'Pop en español', 'Estrenos de la semana',
      'Voces y melodías para cantar a todo volumen.',
      'pop español nuevo sencillo official audio'),
  FeatureCard('ESENCIAL', 'Flamenco', 'Raíz y duende',
      'Del cante jondo a las fusiones más frescas.',
      'flamenco nuevo official audio'),
  FeatureCard('MEZCLA', 'Rock en español', 'Guitarras y directo',
      'Himnos de siempre y bandas que vienen pisando fuerte.',
      'rock en español éxitos official audio'),
  FeatureCard('ELECTRÓNICA', 'Club', 'Para no parar de bailar',
      'Ritmos que no dejan a nadie sentado.',
      'electronic dance nuevo official audio'),
];

const newSongsQuery = 'canciones nuevas esta semana official audio';

const newThisWeek = [
  Collection('Reggaeton nuevo', 'Estrenos', 'reggaeton nuevo official audio'),
  Collection('Pop latino', 'Estrenos', 'pop latino nuevo official audio'),
  Collection('Trap y urbano', 'Estrenos', 'trap español nuevo official audio'),
  Collection('Rock e indie', 'Estrenos', 'indie rock nuevo official audio'),
  Collection('Electrónica', 'Estrenos', 'electronica nuevo official audio'),
  Collection('Flamenco fusión', 'Estrenos', 'flamenco fusion nuevo official audio'),
];

// <FILTRO-DATOS>
// FILTRO DE MUSICA. Todo se compara en minusculas y SIN tildes ni ñ,
// asi que escribe aqui las palabras sin tildes.
// Cada resultado recibe puntos: suma por señales de musica y resta por
// señales de otra cosa. Cuanto mas largo el video, mas puntos exige.

// Si aparece alguna (en titulo o canal), el resultado se descarta siempre.
const hardBlock = [
  r'podcasts?', r'entrevistas?', r'interviews?',
  r'reaccion(?:es|ando|amos)?', r'reactions?', r'reacting',
  r'tutorial(?:es)?', r'gameplay', r'walkthrough', r'lets? play',
  r'trailer', r'episodios?', r'episodes?', r'capitulos?',
  r'temporada \d+', r'noticias?', r'telediario', r'informativo',
  r'documentales?', r'documentary', r'unboxing', r'resenas?', r'reviews?',
  r'audiolibros?', r'audiobooks?', r'asmr', r'sermon(?:es)?', r'predicas?',
  r'conferencias?', r'ponencias?', r'memes?', r'compilacion de',
  r'como (?:hacer|ganar|ser|tocar|aprender|dibujar|cocinar|instalar|crear|preparar|conseguir|arreglar|cambiar|reparar|montar)',
  r'how to', r'lecciones?', r'curso (?:de|completo)', r'clases? de',
  r'resumen del partido', r'highlights', r'programa completo',
  r'full episode', r'stand ?up', r'monologos?', r'vlogs?', r'pranks?',
  r'chistes?', r'recetas?', r'minecraft', r'fortnite', r'roblox',
  r'warzone', r'valorant', r'free fire', r'pelicula completa',
  r'full movie', r'serie completa', r'meditacion guiada',
  r'guided meditation', r'hipnosis', r'debate', r'discurso',
  r'rueda de prensa', r'press conference', r'tertulia', r'#shorts?',
];

// Cada una resta 2 puntos (maximo 4).
const softBlock = [
  r'analisis', r'explicacion', r'explicad[oa]', r'explained',
  r'historia de', r'la historia', r'biografia', r'curiosidades',
  r'top \d+', r'ranking', r'lo que no sabias', r'significado',
  r'meaning of', r'que paso con', r'que significa', r'critica', r'opinion',
  r'bloopers?', r'detras de camaras', r'making of', r'behind the scenes',
  r'teoria', r'aprende', r'aprender',
];

// En el titulo: cada una suma 2 puntos (maximo 4).
const musicHints = [
  r'official (?:audio|video|music video|lyric video|visuali[sz]er)',
  r'(?:audio|video) oficial', r'videoclip', r'video ?clip', r'lyrics?',
  r'letra', r'visuali[sz]er', r'feat\.?', r'ft\.?', r'featuring', r'remix',
  r'acoustic', r'acustico', r'sessions?', r'sesion(?:es)?', r'unplugged',
  r'en vivo', r'live (?:at|from|in|session|performance)', r'prod\.?(?: by)?',
  r'single', r'album', r'instrumental', r'cover', r'bzrp',
];

// En el nombre del canal: suma 2 puntos.
const chanHints = [
  r'vevo', r'records', r'recordings', r'music', r'musica', r'discos', r'label',
];

// Los videos de mas de 30 min solo pasan si el titulo dice una de estas.
const longFormWords = [
  r'full album', r'album completo', r'disco completo', r'mixtape', r'mix',
  r'playlist', r'non ?stop', r'concierto', r'live set', r'dj set',
  r'recopilatorio', r'greatest hits', r'best of', r'lo mejor de',
  r'\d+ ?(?:hours?|horas?)',
];
// </FILTRO-DATOS>
