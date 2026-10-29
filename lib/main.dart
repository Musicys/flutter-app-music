import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_examples.dart';
import 'audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 audio_service 后台服务
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.my_app.channel.audio',
      androidNotificationChannelName: '小猫音乐播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      androidNotificationClickStartsActivity: true,
      preloadArtwork: true,
    ),
  );

  // Android 13+ 请求 POST_NOTIFICATIONS 权限
  await _requestNotificationPermission();

  runApp(const MyApp());
}

Future<void> _requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final MusicController _controller = MusicController();
  final Favorites _favorites = Favorites();
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // 启动时加载本地收藏
    _favorites.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _favorites.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小猫音乐',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEC4141)),
      ),
      home: Stack(
        fit: StackFit.expand,
        children: [
          AppShell(controller: _controller, favorites: _favorites),
          if (_showSplash)
            StartupOverlay(
              onFinished: () => setState(() => _showSplash = false),
            ),
        ],
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.favorites,
  });

  final MusicController controller;
  final Favorites favorites;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'icon.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: _HealingSlogan()),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            controller: widget.controller,
            favorites: widget.favorites,
          ),
          FavoritesPage(
            controller: widget.controller,
            favorites: widget.favorites,
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(
            controller: widget.controller,
            favorites: widget.favorites,
          ),
          NavigationBar(
            selectedIndex: _index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
                tooltip: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: '收藏',
                tooltip: '收藏',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 头像右侧的治愈文案：毛笔字体 + 流动渐变微光
class _HealingSlogan extends StatefulWidget {
  const _HealingSlogan();

  @override
  State<_HealingSlogan> createState() => _HealingSloganState();
}

class _HealingSloganState extends State<_HealingSlogan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final t = _shimmer.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-2 + t * 4, 0),
            end: Alignment(-1 + t * 4, 0),
            colors: const [
              Color(0xFFFF5A7A),
              Color(0xFFFFC46B),
              Color(0xFFB98CFF),
              Color(0xFFFF5A7A),
            ],
          ).createShader(rect),
          child: Text(
            '工作会结束，歌不会',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.maShanZheng(
              fontSize: 20,
              letterSpacing: 1.2,
              color: Colors.white,
              shadows: const [
                Shadow(color: Color(0x33FF5A7A), blurRadius: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 首页默认展示热歌榜：type=search、id=热歌榜、page=1、limit=10
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.favorites,
  });

  final MusicController controller;
  final Favorites favorites;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _pageSize = 20;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Song> _songs = const [];
  bool _loading = true;
  bool _failed = false;
  bool _loadingMore = false; // 防止并发触发

  // 搜索/热歌分页状态
  String _currentKeyword = '热歌榜';
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _fetch('热歌榜');
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_loadingMore || _loading || !_hasMore) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    _fetch(_currentKeyword, page: _currentPage + 1, append: true);
  }

  /// 拉取搜索/热歌列表。[append]=true 时用于分页加载下一页
  Future<void> _fetch(String keyword, {int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _loading = true;
        _failed = false;
        _currentKeyword = keyword;
        _currentPage = 1;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final songs = await widget.controller.service.searchSongs(
        keyword,
        page: page,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _songs = append ? [..._songs, ...songs] : songs;
        _currentPage = page;
        // 返回数量不足 pageSize 说明没有更多了
        _hasMore = songs.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!append) _failed = true;
      });
    }
  }

  void _loadHot() {
    FocusScope.of(context).unfocus();
    _textController.clear();
    _fetch('热歌榜');
  }

  Future<void> _search() async {
    final keyword = _textController.text.trim();
    if (keyword.isEmpty) {
      _loadHot();
      return;
    }
    FocusScope.of(context).unfocus();
    await _fetch(keyword);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _textController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: '搜索歌曲 / 歌手',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.send),
                tooltip: '搜索',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载失败，请检查网络后重试'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _search, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_songs.isEmpty) {
      return const Center(child: Text('没有找到相关歌曲'));
    }
    // 还有下一页时底部加一个加载指示槽位
    final itemCount = _hasMore ? _songs.length + 1 : _songs.length;
    return ListView.builder(
      controller: _scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _songs.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '继续下滑加载更多',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
            ),
          );
        }
        return SongTile(
          song: _songs[index],
          controller: widget.controller,
          favorites: widget.favorites,
          queue: _songs,
        );
      },
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
    required this.controller,
    required this.favorites,
  });

  final MusicController controller;
  final Favorites favorites;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favorites,
      builder: (context, _) {
        final songs = favorites.songs;
        if (songs.isEmpty) {
          return const Center(child: Text('还没有收藏，点击歌曲右侧的 ♡ 收藏'));
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) => SongTile(
            song: songs[index],
            controller: controller,
            favorites: favorites,
            queue: songs,
            queueLabel: '收藏',
          ),
        );
      },
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.controller,
    required this.favorites,
    required this.queue,
    this.queueLabel = '主页',
  });

  final Song song;
  final MusicController controller;
  final Favorites favorites;
  final List<Song> queue;
  final String queueLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favorites,
      builder: (context, _) {
        final liked = favorites.contains(song);
        return ListTile(
          leading: CoverImage(song: song, size: 48, radius: 8),
          title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            onPressed: () => favorites.toggle(song),
            icon: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.redAccent : null,
            ),
            tooltip: liked ? '取消收藏' : '收藏',
          ),
          onTap: () => playSong(
            context,
            controller,
            song,
            queue: queue,
            queueLabel: queueLabel,
          ),
        );
      },
    );
  }
}

class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.song,
    required this.size,
    this.radius = 12,
  });

  final Song song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note,
        size: size * 0.45,
        color: colorScheme.onSurfaceVariant,
      ),
    );

    final pic = song.pic;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: pic == null || pic.isEmpty
          ? placeholder
          : Image.network(
              pic,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.controller,
    required this.favorites,
  });

  final MusicController controller;
  final Favorites favorites;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PlayerPage(controller: controller, favorites: favorites),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: controller.progress,
                  minHeight: 2,
                ),
                ListTile(
                  dense: true,
                  leading: CoverImage(song: song, size: 42, radius: 8),
                  title: Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    controller.isPlaying ? '正在播放' : '已暂停',
                    maxLines: 1,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => controller.togglePlay(),
                        icon: Icon(
                          controller.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        tooltip: controller.isPlaying ? '暂停' : '播放',
                      ),
                      IconButton(
                        onPressed: () => controller.stop(),
                        icon: const Icon(Icons.close),
                        tooltip: '停止',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 播放模式切换按钮：顺序 → 随机 → 单曲循环
class _PlayModeButton extends StatelessWidget {
  const _PlayModeButton({required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    final mode = controller.playMode;
    final (icon, label) = switch (mode) {
      PlayMode.sequence => (Icons.repeat, '顺序播放'),
      PlayMode.shuffle => (Icons.shuffle, '随机播放'),
      PlayMode.repeatOne => (Icons.repeat_one, '单曲循环'),
    };
    final highlight = mode != PlayMode.sequence;
    return IconButton(
      onPressed: () => controller.cyclePlayMode(),
      icon: Icon(icon),
      iconSize: 24,
      color: highlight ? const Color(0xFFFF5A7A) : Colors.white70,
      tooltip: label,
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.controller,
    required this.favorites,
  });

  final MusicController controller;
  final Favorites favorites;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with TickerProviderStateMixin {
  static const _lyricLineHeight = 40.0;
  static const _accent = Color(0xFFFF5A7A);

  final ScrollController _lyricsController = ScrollController();
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final AnimationController _vinylController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final AnimationController _bgController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat(reverse: true);
  late final Animation<Offset> _entryOffset = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
  );

  Song? _lastSong;
  int _lastLyricIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncVinyl);
    _syncVinyl();
  }

  void _syncVinyl() {
    if (!mounted) return;
    if (widget.controller.isPlaying) {
      if (!_vinylController.isAnimating) {
        _vinylController.repeat();
      }
    } else {
      _vinylController.stop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncVinyl);
    _entryController.dispose();
    _vinylController.dispose();
    _glowController.dispose();
    _bgController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  void _scheduleLyricScroll(int index) {
    if (index == _lastLyricIndex) {
      return;
    }
    _lastLyricIndex = index;
    if (index < 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lyricsController.hasClients) return;
      final viewport = _lyricsController.position.viewportDimension;
      final target = (index * _lyricLineHeight +
              _lyricLineHeight / 2 -
              viewport / 2)
          .clamp(0.0, _lyricsController.position.maxScrollExtent)
          .toDouble();
      _lyricsController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('正在播放'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final song = controller.currentSong;
          if (song == null) {
            return const Center(child: Text('暂无播放歌曲'));
          }
          if (!identical(song, _lastSong)) {
            _lastSong = song;
            _lastLyricIndex = -1;
          }

          final currentIndex = controller.currentLyricIndex;
          if (controller.lyrics.isNotEmpty) {
            _scheduleLyricScroll(currentIndex);
          }

          return FadeTransition(
            opacity: _entryController,
            child: SlideTransition(
              position: _entryOffset,
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(
                          -1 + _bgController.value * 0.5,
                          -1,
                        ),
                        end: Alignment(1 - _bgController.value * 0.5, 1),
                        colors: const [
                          Color(0xFF1B1026),
                          Color(0xFF241026),
                          Color(0xFF0C0A13),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _StarFieldPainter(_bgController.value),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                                child: _buildHeader(song, controller),
                              ),
                              Expanded(
                                child: _buildLyrics(controller, currentIndex),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                                child: Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        activeTrackColor: _accent,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                        overlayColor: _accent.withValues(
                                          alpha: 0.25,
                                        ),
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 7,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 18,
                                            ),
                                      ),
                                      child: Slider(
                                        value: controller.sliderValue,
                                        max: controller.sliderMax,
                                        onChanged: controller.sliderMax > 1
                                            ? (value) => controller.seek(
                                                Duration(
                                                  milliseconds: value.round(),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            formatDuration(controller.position),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            formatDuration(controller.duration),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PlayModeButton(controller: controller),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: controller.hasPrevious
                                        ? () => controller.previous()
                                        : null,
                                    icon: const Icon(Icons.skip_previous),
                                    iconSize: 36,
                                    color: Colors.white,
                                    disabledColor: Colors.white24,
                                    tooltip: '上一首',
                                  ),
                                  const SizedBox(width: 16),
                                  AnimatedBuilder(
                                    animation: _glowController,
                                    builder: (context, child) {
                                      final pulse =
                                          0.5 + 0.5 * _glowController.value;
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _accent.withValues(
                                                alpha: controller.isPlaying
                                                    ? 0.28 + 0.2 * pulse
                                                    : 0.2,
                                              ),
                                              blurRadius: controller.isPlaying
                                                  ? 22 + 14 * pulse
                                                  : 18,
                                              spreadRadius: controller.isPlaying
                                                  ? 4 + 4 * pulse
                                                  : 2,
                                            ),
                                          ],
                                        ),
                                        child: child,
                                      );
                                    },
                                    child: IconButton.filled(
                                      style: IconButton.styleFrom(
                                        backgroundColor: _accent,
                                        foregroundColor: Colors.white,
                                      ),
                                      iconSize: 48,
                                      onPressed: controller.isLoadingTrack
                                          ? null
                                          : () => controller.togglePlay(),
                                      icon: Icon(
                                        controller.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                      tooltip: controller.isPlaying
                                          ? '暂停'
                                          : '播放',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    onPressed: controller.hasNext
                                        ? () => controller.next()
                                        : null,
                                    icon: const Icon(Icons.skip_next),
                                    iconSize: 36,
                                    color: Colors.white,
                                    disabledColor: Colors.white24,
                                    tooltip: '下一首',
                                  ),
                                  const SizedBox(width: 8),
                                  // 占位，与左边的播放模式按钮对称
                                  const SizedBox(width: 40),
                                ],
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Song song, MusicController controller) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5A7A).withValues(alpha: 0.35),
                      blurRadius: 26,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              RotationTransition(
                turns: _vinylController,
                child: CustomPaint(
                  size: const Size(92, 92),
                  painter: _VinylRingPainter(),
                ),
              ),
              CoverImage(song: song, size: 64, radius: 12),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '播放列表：${controller.queueLabel}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: widget.favorites,
            builder: (context, _) {
              final liked = widget.favorites.contains(song);
              return IconButton(
                onPressed: () => widget.favorites.toggle(song),
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? _accent : Colors.white70,
                ),
                tooltip: liked ? '取消收藏' : '收藏',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLyrics(MusicController controller, int currentIndex) {
    if (controller.isLoadingLyrics) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }
    final lyrics = controller.lyrics;
    if (lyrics.isEmpty) {
      return const Center(
        child: Text('暂无歌词', style: TextStyle(color: Colors.white38)),
      );
    }
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.12, 0.88, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _lyricsController,
        itemExtent: _lyricLineHeight,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        itemCount: lyrics.length,
        itemBuilder: (context, index) {
          final active = index == currentIndex;
          return Center(
            child: AnimatedScale(
              scale: active ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  fontSize: active ? 19 : 15,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? _accent
                      : Colors.white.withValues(alpha: 0.55),
                  shadows: active
                      ? [
                          Shadow(
                            color: _accent.withValues(alpha: 0.7),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  lyrics[index].text,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MusicController extends ChangeNotifier {
  final MetingService service = MetingService();

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;

  Song? _currentSong;
  AudioProcessingState _processingState = AudioProcessingState.idle;
  bool _playing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<LyricLine> _lyrics = const [];
  bool _loadingLyrics = false;
  PlayMode _playMode = PlayMode.sequence;

  MusicController() {
    _subscriptions.addAll([
      audioHandler.playbackState.listen(_onPlaybackState),
      audioHandler.mediaItem.listen(_onMediaItem),
      audioHandler.playModeStream.listen((mode) {
        _playMode = mode;
        _notify();
      }),
    ]);
  }

  Song? get currentSong => _currentSong;
  AudioProcessingState get playerState => _processingState;
  Duration get duration => _duration;
  Duration get position => _position;
  PlayMode get playMode => _playMode;
  List<LyricLine> get lyrics => _lyrics;
  bool get isLoadingTrack => audioHandler.isLoadingTrack;
  bool get isLoadingLyrics => _loadingLyrics;
  bool get isPlaying => _playing;
  bool get hasPrevious => audioHandler.hasPrevious;
  bool get hasNext => audioHandler.hasNext;
  String get queueLabel => audioHandler.queueLabelName;

  double get progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get sliderMax {
    final ms = _duration.inMilliseconds.toDouble();
    return ms > 0 ? ms : 1;
  }

  double get sliderValue {
    final ms = _position.inMilliseconds.toDouble();
    return ms.clamp(0.0, sliderMax).toDouble();
  }

  int get currentLyricIndex {
    if (_lyrics.isEmpty) return -1;
    final ms = _position.inMilliseconds;
    var index = -1;
    for (var i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].time.inMilliseconds <= ms) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onPlaybackState(PlaybackState state) {
    _playing = state.playing;
    _processingState = state.processingState;
    _position = state.updatePosition;
    _notify();
  }

  void _onMediaItem(MediaItem? item) {
    final previousSong = _currentSong;

    if (item == null) {
      _currentSong = null;
      _duration = Duration.zero;
      _position = Duration.zero;
      _lyrics = const [];
      _loadingLyrics = false;
      _notify();
      return;
    }

    // 优先取播放队列里的原始 Song（pic / lrc 等完整元数据），
    // 只有队列不可用（如通知栏外部触发）时才回退到 MediaItem 反序列化
    final queueSong = audioHandler.currentSong;
    final Song newSong = queueSong != null && songKey(queueSong) == item.id
        ? queueSong
        : _songFromMediaItem(item);

    final isNewSong =
        previousSong == null || songKey(previousSong) != songKey(newSong);

    _currentSong = newSong;

    if (isNewSong) {
      // 切歌时重置进度/时长，避免进度条沿用上一首的时长
      _duration = item.duration ?? Duration.zero;
      _position = Duration.zero;
      _lyrics = const [];
      _loadingLyrics = false;
      _startLoadLyrics(newSong);
    } else if (item.duration != null && item.duration != _duration) {
      // 同一首歌的时长补全（如 just_audio 解析出真实时长）
      _duration = item.duration!;
    }

    _notify();
  }

  Song _songFromMediaItem(MediaItem item) {
    final extras = item.extras ?? const <String, dynamic>{};
    return Song(
      id: item.id,
      name: item.title,
      artist: item.artist ?? '未知歌手',
      album: item.album,
      pic: extras['pic'] as String?,
      url: extras['url'] as String?,
      lrc: extras['lrc'] as String?,
      lrcText: extras['lrcText'] as String?,
      subLrc: extras['subLrc'] as String?,
      br: extras['br'] as int?,
    );
  }

  /// 切歌/首次播放时统一的歌词加载入口
  void _startLoadLyrics(Song song) {
    final lrcText = song.lrcText;
    if (lrcText != null && lrcText.trim().isNotEmpty) {
      _lyrics = parseLrc(lrcText);
      return;
    }
    final lrcUrl = song.lrc;
    if (lrcUrl == null || lrcUrl.isEmpty) {
      return;
    }
    _loadingLyrics = true;
    unawaited(_loadLyrics(lrcUrl, song));
  }

  Future<void> _loadLyrics(String url, Song song) async {
    final key = songKey(song);
    try {
      final text = await service.fetchLyrics(url);
      if (_currentSong == null || songKey(_currentSong!) != key) return;
      _lyrics = parseLrc(text);
    } catch (_) {
      if (_currentSong == null || songKey(_currentSong!) != key) return;
      _lyrics = const [];
    } finally {
      if (_currentSong != null && songKey(_currentSong!) == key) {
        _loadingLyrics = false;
        _notify();
      }
    }
  }

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    String? queueLabel,
  }) async {
    // 立即用点击的原始 Song 更新 UI（封面 / 歌词），
    // 不等 audio_service 的 MediaItem 回流，避免切歌时元数据缺失
    _currentSong = song;
    _duration = Duration.zero;
    _position = Duration.zero;
    _lyrics = const [];
    _loadingLyrics = false;
    _startLoadLyrics(song);
    _notify();

    await audioHandler.playSong(song, queue: queue, queueLabel: queueLabel);
  }

  Future<void> next() async => audioHandler.next();

  Future<void> previous() async => audioHandler.previous();

  /// 切换播放模式：顺序 → 随机 → 单曲循环
  Future<PlayMode> cyclePlayMode() => audioHandler.cyclePlayMode();

  Future<void> togglePlay() async {
    if (_currentSong == null) return;
    if (_playing) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await audioHandler.seek(position);
  }

  Future<void> stop() async {
    await audioHandler.stop();
    _currentSong = null;
    _duration = Duration.zero;
    _position = Duration.zero;
    _lyrics = const [];
    _loadingLyrics = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

class Favorites extends ChangeNotifier {
  final List<Song> _songs = [];
  static const String _storageKey = 'favorites_v1';
  bool _loaded = false;

  List<Song> get songs => List.unmodifiable(_songs);

  bool contains(Song song) {
    final key = songKey(song);
    return _songs.any((item) => songKey(item) == key);
  }

  /// 启动时从本地存储加载收藏列表
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? const [];
      _songs
        ..clear()
        ..addAll(
          raw
              .map((s) => Song.fromJson(jsonDecode(s) as Map<String, dynamic>))
              .toList(),
        );
    } catch (_) {
      // 数据损坏时静默恢复为空
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKey,
        _songs.map((s) => jsonEncode(s.toJson())).toList(),
      );
    } catch (_) {
      // 持久化失败不影响当次操作
    }
  }

  void toggle(Song song) {
    final key = songKey(song);
    if (_songs.any((item) => songKey(item) == key)) {
      _songs.removeWhere((item) => songKey(item) == key);
    } else {
      _songs.add(song);
    }
    notifyListeners();
    unawaited(_save());
  }
}

String songKey(Song song) {
  return song.id.isNotEmpty ? song.id : '${song.name}|${song.artist}';
}

Future<void> playSong(
  BuildContext context,
  MusicController controller,
  Song song, {
  List<Song>? queue,
  String? queueLabel,
}) async {
  try {
    await controller.playSong(song, queue: queue, queueLabel: queueLabel);
  } catch (error) {
    if (!context.mounted) return;
    const prefix = 'Exception: ';
    final message = error.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.startsWith(prefix) ? message.substring(prefix.length) : message,
        ),
      ),
    );
  }
}

String formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// 启动初始化动画：光环扩散、星点环绕、底部律动条
class StartupOverlay extends StatefulWidget {
  const StartupOverlay({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<StartupOverlay> createState() => _StartupOverlayState();
}

class _StartupOverlayState extends State<StartupOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final fadeOut = Interval(0.85, 1.0).transform(t);
          final titleT = Curves.easeOutCubic.transform(
            Interval(0.15, 0.45).transform(t),
          );
          final subT = Curves.easeOut.transform(
            Interval(0.32, 0.6).transform(t),
          );
          final logoScale = 0.9 +
              0.1 * Curves.easeOutBack.transform(Interval(0.0, 0.4).transform(t));

          return Opacity(
            opacity: (1 - fadeOut).clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.25),
                  radius: 1.15,
                  colors: [
                    Color(0xFF2B1530),
                    Color(0xFF150F1F),
                    Color(0xFF07060B),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _StartupPainter(t)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: logoScale,
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF5A7A,
                                  ).withValues(alpha: 0.45),
                                  blurRadius: 34,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'icon.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Opacity(
                          opacity: titleT,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - titleT)),
                            child: const Text(
                              '小猫音乐',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: subT,
                          child: Container(
                            width: 64,
                            height: 2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF5A7A), Color(0xFFFFD166)],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Opacity(
                          opacity: subT,
                          child: const Text(
                            '正在唤醒音乐…',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StartupPainter extends CustomPainter {
  _StartupPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - size.height * 0.05);
    const accent = Color(0xFFFF5A7A);
    const warm = Color(0xFFFFD166);

    const glowPaint = RadialGradient(
      colors: [Color(0x33FF5A7A), Color(0x00000000)],
    );
    canvas.drawCircle(
      center,
      200,
      Paint()
        ..shader = glowPaint.createShader(
          Rect.fromCircle(center: center, radius: 200),
        ),
    );

    for (var i = 0; i < 3; i++) {
      final local = (progress * 1.6 + i / 3) % 1.0;
      canvas.drawCircle(
        center,
        40 + local * 210,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = accent.withValues(alpha: (1 - local) * 0.35),
      );
    }

    for (var i = 0; i < 8; i++) {
      final angle = progress * math.pi * 2 * 1.4 + i * math.pi / 4;
      final wobble = 8 * math.sin(progress * math.pi * 4 + i);
      final orbit = 96 + wobble;
      final point = Offset(
        center.dx + math.cos(angle) * orbit,
        center.dy + math.sin(angle) * orbit,
      );
      canvas.drawCircle(
        point,
        2.2,
        Paint()
          ..color = (i.isEven ? accent : warm).withValues(alpha: 0.75),
      );
    }

    const barCount = 15;
    final barWidth = size.width / (barCount * 2.4);
    final baseY = size.height * 0.79;
    for (var i = 0; i < barCount; i++) {
      final phase = progress * math.pi * 4 + i * 0.6;
      final amplitude = 18 + 30 * (0.5 + 0.5 * math.sin(phase));
      final x = size.width / 2 + (i - (barCount - 1) / 2) * barWidth * 1.9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - amplitude / 2, barWidth, amplitude),
          const Radius.circular(3),
        ),
        Paint()
          ..color = (i < barCount / 2 ? accent : warm).withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StartupPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.7 + random.nextDouble() * 1.5;
      final twinkle = 0.5 + 0.5 * math.sin(progress * math.pi * 4 + i);
      final color = i.isEven
          ? const Color(0xFFFF5A7A)
          : const Color(0xFFFFD166);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: 0.1 + 0.3 * twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _VinylRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF5A7A).withValues(alpha: 0.55);
    for (var i = 0; i < 12; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * math.pi / 6,
        0.18,
        false,
        dashPaint,
      );
    }

    canvas.drawCircle(
      center,
      2.6,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
