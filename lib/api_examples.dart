import 'dart:convert';
import 'package:http/http.dart' as http;

/// Meting API 服务
class MetingService {
  final String baseUrl = 'https://api.qijieya.cn/meting/';

  /// 搜索歌曲
  Future<List<Song>> searchSongs(String keyword, {int page = 1, int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$baseUrl?type=search&id=${Uri.encodeComponent(keyword)}&page=$page&limit=$limit'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => Song.fromJson(json)).toList();
    } else {
      throw Exception('搜索失败: ${response.statusCode}');
    }
  }

  /// 获取歌曲详情
  Future<Song> getSongDetail(String id) async {
    final response = await http.get(Uri.parse('$baseUrl?type=song&id=$id'));
    if (response.bodyBytes.isNotEmpty) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return Song.fromJson(data);
    } else {
      throw Exception('获取歌曲详情失败: ${response.statusCode}');
    }
  }

  /// 获取播放链接
  Future<String> getSongUrl(String id, {int? bitrate}) async {
    final response = await http.get(
      Uri.parse('$baseUrl?type=url&id=$id${bitrate != null ? '&br=$bitrate' : ''}'),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data['url'] as String;
    } else {
      throw Exception('获取播放链接失败: ${response.statusCode}');
    }
  }

  /// 获取歌词
  Future<String> getLyrics(String id) async {
    final response = await http.get(Uri.parse('$baseUrl?type=lrc&id=$id'));
    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception('获取歌词失败: ${response.statusCode}');
    }
  }

  /// 通过搜索结果里的 lrc 地址获取歌词文本
  Future<String> fetchLyrics(String rawUrl) async {
    final response = await http.get(Uri.parse(rawUrl));
    if (response.statusCode != 200) {
      throw Exception('获取歌词失败: ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  /// 获取歌单
  Future<Playlist> getPlaylist(String id) async {
    final response = await http.get(Uri.parse('$baseUrl?type=playlist&id=$id'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return Playlist.fromJson(data);
    } else {
      throw Exception('获取歌单失败: ${response.statusCode}');
    }
  }

  /// 获取封面图
  Future<String> getCover(String id, {int coverSize = 300}) async {
    final response = await http.get(
      Uri.parse('$baseUrl?type=pic&id=$id&cover=$coverSize'),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data['pic'] as String;
    } else {
      throw Exception('获取封面失败: ${response.statusCode}');
    }
  }
}

/// 歌曲数据模型
class Song {
  final String id;
  final String name;
  final String artist;
  final String? album;
  final String? pic;
  final String? url;
  final String? lrc;
  final String? lrcText; // 内联歌词文本（ACGM 接口直接返回文本而非 URL）
  final String? subLrc; // 翻译/副歌词
  final int? br; // 音质: 128, 192, 320, 2000(FLAC)

  Song({
    required this.id,
    required this.name,
    required this.artist,
    this.album,
    this.pic,
    this.url,
    this.lrc,
    this.lrcText,
    this.subLrc,
    this.br,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    final rawId = json['id']?.toString() ?? '';
    return Song(
      // 搜索结果可能没有 id 字段，从 url 里兜底提取
      id: rawId.isEmpty ? _idFromUrl(url) : rawId,
      name: json['name'] as String? ?? '未知歌曲',
      artist: json['artist'] as String? ?? '未知歌手',
      album: json['album'] as String?,
      pic: json['pic'] as String?,
      url: json['url'] as String?,
      lrc: json['lrc'] as String?,
      lrcText: json['lrcText'] as String?,
      subLrc: json['subLrc'] as String?,
      br: json['br'] as int?,
    );
  }

  static String _idFromUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    return Uri.tryParse(url)?.queryParameters['id'] ?? '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'album': album,
      'pic': pic,
      'url': url,
      'lrc': lrc,
      'lrcText': lrcText,
      'subLrc': subLrc,
      'br': br,
    };
  }
}

/// 歌单数据模型
class Playlist {
  final String id;
  final String name;
  final String? cover;
  final List<Song> tracks;

  Playlist({
    required this.id,
    required this.name,
    this.cover,
    required this.tracks,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final tracks = (json['tracks'] as List<dynamic>?)
            ?.map((t) => Song.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未知歌单',
      cover: json['cover'] as String?,
      tracks: tracks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cover': cover,
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };
  }
}

/// 一行带时间戳的歌词
class LyricLine {
  final Duration time;
  final String text;

  const LyricLine(this.time, this.text);
}

/// 解析 LRC 歌词，支持一行多个时间标签，如 [02:16.30][00:26.00]歌词
List<LyricLine> parseLrc(String source) {
  final timeTag = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  final result = <LyricLine>[];

  for (final rawLine in source.split(RegExp(r'\r?\n'))) {
    final matches = timeTag.allMatches(rawLine).toList();
    if (matches.isEmpty) {
      continue;
    }
    final text = rawLine.replaceAll(timeTag, '').trim();
    if (text.isEmpty) {
      continue;
    }

    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = (match.group(3) ?? '0').padRight(3, '0').substring(0, 3);
      result.add(
        LyricLine(
          Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: int.parse(fraction),
          ),
          text,
        ),
      );
    }
  }

  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}
