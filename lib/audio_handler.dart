import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'api_examples.dart';

/// 全局 audio_service 实例，在 main() 中初始化
late final MyAudioHandler audioHandler;

/// 同 main.dart 的 songKey，避免循环 import
String _songKey(Song song) {
  return song.id.isNotEmpty ? song.id : '${song.name}|${song.artist}';
}

/// 将应用的 [Song] 转成 audio_service 的 [MediaItem]
Future<MediaItem> songToMediaItem(Song song) async {
  final pic = song.pic;
  return MediaItem(
    id: song.id,
    album: song.album ?? '未知专辑',
    title: song.name,
    artist: song.artist,
    duration: null,
    artUri: pic != null && pic.isNotEmpty ? Uri.parse(pic) : null,
    extras: {
      'pic': pic,
      'url': song.url,
      'lrc': song.lrc,
      'lrcText': song.lrcText,
      'subLrc': song.subLrc,
      'br': song.br,
    },
  );
}

/// 播放模式：顺序 / 随机 / 单曲循环
enum PlayMode { sequence, shuffle, repeatOne }

extension PlayModeX on PlayMode {
  PlayMode get next => switch (this) {
    PlayMode.sequence => PlayMode.shuffle,
    PlayMode.shuffle => PlayMode.repeatOne,
    PlayMode.repeatOne => PlayMode.sequence,
  };
}

/// 负责底层播放 + 后台通知栏的 AudioHandler
class MyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final MetingService _service = MetingService();
  final math.Random _random = math.Random();

  List<Song> _queue = const [];
  int _queueIndex = -1;
  String _queueLabel = '主页';
  bool _loading = false;
  PlayMode _playMode = PlayMode.sequence;

  int get queueIndex => _queueIndex;
  String get queueLabelName => _queueLabel;
  bool get isLoadingTrack => _loading;
  PlayMode get playMode => _playMode;

  /// 当前队列中正在播放的原始 Song（含封面 / 歌词等完整元数据）
  Song? get currentSong =>
      _queueIndex >= 0 && _queueIndex < _queue.length
          ? _queue[_queueIndex]
          : null;

  /// 播放模式变化广播
  final StreamController<PlayMode> _playModeController =
      StreamController<PlayMode>.broadcast();
  Stream<PlayMode> get playModeStream => _playModeController.stream;

  MyAudioHandler() {
    _player.playerStateStream.listen(_onPlayerState);
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });
    _player.bufferedPositionStream.listen((buffered) {
      playbackState.add(playbackState.value.copyWith(bufferedPosition: buffered));
    });
    // 流媒体时长可能异步解析出来，同步到 MediaItem 让进度条准确
    _player.durationStream.listen((duration) {
      if (duration == null) return;
      _updateMediaDuration(duration);
    });
    // 播放完成 → 根据播放模式决定下一步
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _playerCompleted();
      }
    });
  }

  bool get hasPrevious => _queueIndex > 0;
  bool get hasNext =>
      _queueIndex >= 0 &&
      (_queueIndex + 1 < _queue.length || _playMode == PlayMode.shuffle);

  void _onPlayerState(PlayerState state) {
    final audioState = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[state.processingState]!;

    playbackState.add(playbackState.value.copyWith(
      playing: state.playing,
      processingState: audioState,
      controls: _buildControls(playing: state.playing),
    ));
  }

  void _playerCompleted() {
    switch (_playMode) {
      case PlayMode.repeatOne:
        // 单曲循环：重播当前
        unawaited(_replayCurrent());
        break;
      case PlayMode.shuffle:
        // 随机：随机挑一首（队列长度 >1 时避开当前）
        unawaited(_playRandom());
        break;
      case PlayMode.sequence:
        if (hasNext) unawaited(skipToNext());
        break;
    }
  }

  Future<void> _replayCurrent() async {
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> _playRandom() async {
    if (_queue.isEmpty) return;
    int nextIndex;
    if (_queue.length == 1) {
      nextIndex = 0;
    } else {
      do {
        nextIndex = _random.nextInt(_queue.length);
      } while (nextIndex == _queueIndex);
    }
    _queueIndex = nextIndex;
    await _playQueueIndex();
  }

  /// 切换播放模式：顺序 → 随机 → 单曲循环 → 顺序
  Future<PlayMode> cyclePlayMode() async {
    _playMode = _playMode.next;
    _playModeController.add(_playMode);
    // 通知栏的 controls 依赖 hasNext，模式变化可能影响下一首可用性
    playbackState.add(playbackState.value.copyWith(
      controls: _buildControls(playing: playbackState.value.playing),
    ));
    return _playMode;
  }

  /// ========= 播放控制 =========

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _queue = const [];
    _queueIndex = -1;
    _queueLabel = '主页';
    _loading = false;
    queue.add(const []);
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      controls: [MediaControl.play],
      updatePosition: Duration.zero,
    ));
  }

  @override
  Future<void> skipToNext() async {
    // 随机模式下"下一首"也是随机选
    if (_playMode == PlayMode.shuffle) {
      await _playRandom();
      return;
    }
    if (!hasNext) return;
    _queueIndex++;
    await _playQueueIndex();
  }

  @override
  Future<void> skipToPrevious() async {
    if (!hasPrevious) return;
    _queueIndex--;
    await _playQueueIndex();
  }

  /// ========= 业务方法（供 MusicController 调用）=========

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    String? queueLabel,
  }) async {
    if (queue != null) {
      _queue = List.unmodifiable(queue);
      _queueIndex = _indexOfInQueue(song);
      if (queueLabel != null) _queueLabel = queueLabel;
      final items = await Future.wait(_queue.map(songToMediaItem));
      this.queue.add(items);
    }
    await _playQueueIndex();
  }

  Future<void> next() => skipToNext();
  Future<void> previous() => skipToPrevious();

  int _indexOfInQueue(Song song) {
    final identityIndex = _queue.indexWhere((item) => identical(item, song));
    if (identityIndex >= 0) return identityIndex;
    final key = _songKey(song);
    return _queue.indexWhere((item) => _songKey(item) == key);
  }

  Future<void> _playQueueIndex() async {
    if (_queueIndex < 0 || _queueIndex >= _queue.length) return;
    final song = _queue[_queueIndex];
    _loading = true;

    final item = await songToMediaItem(song);
    mediaItem.add(item);

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      controls: _buildControls(playing: false),
      updatePosition: Duration.zero,
    ));

    try {
      await _player.stop();
      final playUrl = song.url != null && song.url!.isNotEmpty
          ? song.url!
          : '${_service.baseUrl}?server=netease&type=url&id=${song.id}';

      final duration = await _player.setUrl(playUrl);
      _loading = false;

      await _player.play();

      if (duration != null) {
        _updateMediaDuration(duration);
      }
    } catch (e) {
      _loading = false;
      rethrow;
    }
  }

  /// 把 just_audio 解析出的真实时长同步到 MediaItem，保证进度条准确
  void _updateMediaDuration(Duration duration) {
    final current = mediaItem.value;
    if (current == null) return;
    if (current.duration == duration) return;
    mediaItem.add(current.copyWith(duration: duration));
  }

  List<MediaControl> _buildControls({required bool playing}) {
    final list = <MediaControl>[];
    if (hasPrevious) list.add(MediaControl.skipToPrevious);
    list.add(playing ? MediaControl.pause : MediaControl.play);
    if (hasNext) list.add(MediaControl.skipToNext);
    return list;
  }

  @override
  Future<void> onTaskRemoved() async {
    await _playModeController.close();
    await super.onTaskRemoved();
  }
}
