class Track {
  final String id;
  final String title;
  final String artist;
  final String thumb;
  final int? seconds;
  final String? album;
  final List<String> radioTags;
  final String? channelId;
  final String? streamUrl;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumb,
    this.seconds,
    this.album,
    this.radioTags = const [],
    this.channelId,
    this.streamUrl,
  });

  String get displayTitle {
    final cleanArtist = artist.trim();
    if (cleanArtist.isEmpty) return title.trim();
    final escaped = RegExp.escape(cleanArtist);
    return title
        .trim()
        .replaceFirst(
          RegExp('^$escaped\\s*[-–—:|]\\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp('\\s*[-–—|]\\s*${escaped}\$', caseSensitive: false),
          '',
        )
        .trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumb': thumb,
        'seconds': seconds,
        'album': album,
        'radioTags': radioTags,
        'channelId': channelId,
        'streamUrl': streamUrl,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String,
        thumb: j['thumb'] as String,
        seconds: j['seconds'] as int?,
        album: j['album'] as String?,
        radioTags: (j['radioTags'] as List? ?? const []).cast<String>(),
        channelId: j['channelId'] as String?,
        streamUrl: j['streamUrl'] as String?,
      );
}

class UserPlaylist {
  final String id;
  final String name;
  final List<Track> tracks;
  final String? customCoverPath;

  const UserPlaylist({
    required this.id,
    required this.name,
    this.tracks = const [],
    this.customCoverPath,
  });

  String get cover =>
      customCoverPath ?? (tracks.isEmpty ? '' : tracks.first.thumb);

  UserPlaylist copyWith({
    String? name,
    List<Track>? tracks,
    String? customCoverPath,
    bool clearCustomCover = false,
  }) =>
      UserPlaylist(
        id: id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        customCoverPath:
            clearCustomCover ? null : customCoverPath ?? this.customCoverPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((track) => track.toJson()).toList(),
        'customCoverPath': customCoverPath,
      };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        tracks: [
          for (final track in (json['tracks'] as List? ?? const []))
            Track.fromJson(Map<String, dynamic>.from(track as Map)),
        ],
        customCoverPath: json['customCoverPath'] as String?,
      );
}

class SavedAlbum {
  final String id;
  final String title;
  final String image;
  final String subtitle;
  final String artistName;
  final String artistImage;
  final String artistChannelId;

  const SavedAlbum({
    required this.id,
    required this.title,
    required this.image,
    required this.subtitle,
    required this.artistName,
    required this.artistImage,
    required this.artistChannelId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image': image,
        'subtitle': subtitle,
        'artistName': artistName,
        'artistImage': artistImage,
        'artistChannelId': artistChannelId,
      };

  factory SavedAlbum.fromJson(Map<String, dynamic> json) => SavedAlbum(
        id: json['id'] as String,
        title: json['title'] as String,
        image: json['image'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        artistName: json['artistName'] as String,
        artistImage: json['artistImage'] as String? ?? '',
        artistChannelId: json['artistChannelId'] as String? ?? '',
      );
}

/// Una "lista" = una búsqueda en YouTube con nombre bonito.
class Collection {
  final String title;
  final String subtitle;
  final String query;
  final int color;
  const Collection(this.title, this.subtitle, this.query,
      [this.color = 0xFF3A3A3C]);
}

class Artist {
  final String name;
  final String image;
  final String channelId;
  const Artist(
      {required this.name, required this.image, required this.channelId});

  Map<String, dynamic> toJson() =>
      {'name': name, 'image': image, 'channelId': channelId};

  factory Artist.fromJson(Map<String, dynamic> j) => Artist(
        name: j['name'] as String,
        image: j['image'] as String,
        channelId: j['channelId'] as String,
      );
}

const kazeOfficialChannelId = 'UCtM7PNfeDJoUDBiB8uWWDug';

Artist canonicalArtist(Artist artist) {
  final normalizedName = artist.name
      .toLowerCase()
      .replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*vevo$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  if (normalizedName != 'kaze') return artist;
  return const Artist(
    name: 'KAZE',
    image: '',
    channelId: kazeOfficialChannelId,
  );
}
