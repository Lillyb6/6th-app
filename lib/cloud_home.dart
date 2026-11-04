import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_api.dart';
import 'cloud_api.dart';
import 'cloud_theme.dart';
import 'cloud_widgets.dart';

class CloudClubHome extends StatefulWidget {
  const CloudClubHome({
    super.key,
    required this.api,
    this.name = 'Cloud watcher',
    this.onLogout,
    this.photoPicker = choosePhoto,
  });
  final CloudApi api;
  final String name;
  final VoidCallback? onLogout;
  final Future<String?> Function() photoPicker;
  @override
  State<CloudClubHome> createState() => _CloudClubHomeState();
}

class _CloudClubHomeState extends State<CloudClubHome> {
  int _tab = 0;
  List<CloudPhoto> _feed = [], _own = [];
  int? _next, _ownNext;
  Map<String, dynamic> _profile = {};
  bool _loading = true, _more = false;
  String? _error;
  late final CloudApi _api = widget.api;
  String get _name => _profile['name'] as String? ?? widget.name;
  String get _avatar => _profile['avatar'] as String? ?? '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.request('/feed'),
        _api.request('/profile'),
        _api.request('/profile/posts'),
      ]);
      if (!mounted) return;
      setState(() {
        _feed = _photos(results[0]);
        _next = results[0]['next'] as int?;
        _profile = results[1];
        _own = _photos(results[2]);
        _ownNext = results[2]['next'] as int?;
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CloudPhoto> _photos(Map<String, dynamic> data) => (data['posts'] as List)
      .map((p) => CloudPhoto(p as Map<String, dynamic>))
      .toList();
  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _loadMore(bool own) async {
    if (_more) return;
    setState(() => _more = true);
    try {
      final result = await _api.request(
        '${own ? '/profile/posts' : '/feed'}?before=${own ? _ownNext : _next}',
      );
      if (!mounted) return;
      setState(() {
        if (own) {
          _own.addAll(_photos(result));
          _ownNext = result['next'] as int?;
        } else {
          _feed.addAll(_photos(result));
          _next = result['next'] as int?;
        }
      });
    } on AuthException catch (e) {
      _notice(e.message);
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  Future<void> _like(CloudPhoto post) async {
    try {
      final r = await _api.request(
        '/posts/${post.id}/like',
        data: {'liked': !post.liked},
      );
      if (!mounted) return;
      setState(() {
        for (final p in [..._feed, ..._own]) {
          if (p.id == post.id) {
            p.liked = r['liked'] as bool;
            p.likes = r['likes'] as int;
          }
        }
      });
    } on AuthException catch (e) {
      _notice(e.message);
    }
  }

  Future<void> _best(CloudPhoto post) async {
    try {
      await _api.request('/posts/${post.id}/best', data: {'best': !post.best});
      if (!mounted) return;
      setState(() {
        final value = !post.best;
        for (final p in [..._feed, ..._own]) {
          if (p.id == post.id) p.best = value;
        }
      });
    } on AuthException catch (e) {
      _notice(e.message);
    }
  }

  Future<void> _delete(CloudPhoto post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this cloud?'),
        content: const Text(
          'This photo will be removed from your profile and the community feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete photo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.request('/posts/${post.id}/delete', data: {});
      if (!mounted) return;
      setState(() {
        _feed.removeWhere((p) => p.id == post.id);
        _own.removeWhere((p) => p.id == post.id);
      });
    } on AuthException catch (e) {
      _notice(e.message);
    }
  }

  Future<void> _editProfile() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProfileEditor(
        api: _api,
        profile: {
          'name': _name,
          'bio': _profile['bio'] ?? '',
          'avatar': _avatar,
        },
        picker: widget.photoPicker,
      ),
    );
    if (saved == true) await _load();
  }

  void _detail(CloudPhoto p) => showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close photo',
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close),
                ),
              ),
              CloudPost(
                post: p,
                own: true,
                onLike: () async {
                  await _like(p);
                  if (c.mounted) Navigator.pop(c);
                },
                onBest: () async {
                  await _best(p);
                  if (c.mounted) Navigator.pop(c);
                },
                onDelete: () {
                  Navigator.pop(c);
                  _delete(p);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      final main = Column(
        children: [
          _header(wide),
          Expanded(
            child: Padding(
              padding: wide
                  ? const EdgeInsets.only(right: 16, bottom: 16)
                  : EdgeInsets.zero,
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(wide ? 22 : 0),
                child: _tab == 1
                    ? UploadCloud(
                        key: const ValueKey('upload'),
                        picker: widget.photoPicker,
                        api: _api,
                        name: _name,
                        avatar: _avatar,
                        onPosted: () async {
                          setState(() => _tab = 0);
                          await _load();
                          _notice('Your cloud is out in the world.');
                        },
                      )
                    : _tab == 2
                    ? _profileView()
                    : _feedView(),
              ),
            ),
          ),
        ],
      );
      return Scaffold(
        backgroundColor: cloudGround,
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (wide) _sidebar(),
              Expanded(child: main),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.cloud_outlined),
                    selectedIcon: Icon(Icons.cloud),
                    label: 'Clouds',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add),
                    selectedIcon: Icon(Icons.add_circle_outline),
                    label: 'Post',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
      );
    },
  );
  Widget _header(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(wide ? 24 : 20, 8, wide ? 32 : 12, 8),
    child: SizedBox(
      height: 52,
      child: Row(
        children: [
          if (!wide)
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CloudWordmark(),
              ),
            ),
          if (wide)
            Text(
              ['The cloud feed', 'A new cloud', 'Your profile'][_tab],
              style: const TextStyle(color: cloudMuted),
            ),
          const Spacer(),
          if (wide)
            const Text(
              'A little less scrolling. A little more sky.',
              style: TextStyle(fontSize: 13, color: cloudMuted),
            ),
          const SizedBox(width: 12),
          if (!wide && widget.onLogout != null)
            IconButton(
              tooltip: 'Log out',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, size: 20),
            ),
          if (wide)
            InkWell(
              onTap: () => setState(() => _tab = 2),
              borderRadius: BorderRadius.circular(24),
              child: CloudAvatar(name: _name, data: _avatar, radius: 17),
            ),
        ],
      ),
    ),
  );
  Widget _sidebar() => SizedBox(
    width: 224,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FittedBox(fit: BoxFit.scaleDown, child: CloudWordmark()),
          const SizedBox(height: 56),
          for (final (index, icon, label) in [
            (0, Icons.cloud_outlined, 'Clouds'),
            (1, Icons.add, 'Post a cloud'),
            (2, Icons.person_outline, 'Profile'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                selected: _tab == index,
                selectedTileColor: const Color(0xFFE4EBEF),
                selectedColor: cloudInk,
                leading: Icon(icon, size: 22),
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _tab == index
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                onTap: () => setState(() => _tab = index),
              ),
            ),
          const Spacer(),
          const Icon(Icons.cloud_outlined, size: 36, color: Color(0xFF8199A7)),
          const SizedBox(height: 12),
          const Text(
            'For the ones who\nalways look up.',
            style: TextStyle(
              fontFamily: 'Instrument Serif',
              fontSize: 25,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              CloudAvatar(name: _name, data: _avatar, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (widget.onLogout != null)
                IconButton(
                  tooltip: 'Log out',
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout, size: 18),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _state() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
    child: Column(
      children: [
        if (_loading) ...[
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          const Text('Gathering the clouds...'),
        ] else ...[
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ],
    ),
  );
  Widget _feedView() => RefreshIndicator(
    onRefresh: _load,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final rail = constraints.maxWidth >= 850;
        // At 1100px: 40 + 680 + 24 + 256 + 40 = 1040, within the shared canvas.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 20 : 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Look up, ${_name.split(' ').first}.',
                    style: const TextStyle(
                      fontFamily: 'Instrument Serif',
                      fontSize: 32,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Different people. The same sky.',
                    style: TextStyle(color: cloudMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Around the club',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Refresh clouds',
                                  onPressed: _loading ? null : _load,
                                  icon: const Icon(Icons.refresh, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_loading || _error != null)
                              _state()
                            else if (_feed.isEmpty)
                              _emptyFeed()
                            else ...[
                              for (final p in _feed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 28),
                                  child: CloudPost(
                                    post: p,
                                    own: p.userId == _profile['id'],
                                    onLike: () => _like(p),
                                    onBest: () => _best(p),
                                    onDelete: () => _delete(p),
                                  ),
                                ),
                              if (_next != null)
                                OutlinedButton(
                                  onPressed: _more
                                      ? null
                                      : () => _loadMore(false),
                                  child: Text(
                                    _more ? 'Loading...' : 'More clouds',
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      if (rail) ...[
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _clubNote()),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  Widget _emptyFeed() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: Image.asset(
            'assets/blue-sky-background-clouds.webp',
            fit: BoxFit.cover,
            semanticLabel: 'White cumulus clouds against a blue sky',
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'The sky is open.',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      const Text(
        'Be the first to leave a little piece of your sky here. Photos from the community will appear in this feed.',
        style: TextStyle(color: cloudMuted, height: 1.6),
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => setState(() => _tab = 1),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Post the first cloud'),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Welcome photo: “Blue sky background clouds” · CC0 · rawpixel',
        style: TextStyle(fontSize: 12, color: cloudMuted),
      ),
    ],
  );
  Widget _clubNote() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: cloudGround,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CloudAvatar(name: _name, data: _avatar, radius: 24),
        const SizedBox(height: 16),
        Text(
          _name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          (_profile['bio'] as String? ?? '').isEmpty
              ? 'Your own little patch of sky.'
              : _profile['bio'] as String,
          style: const TextStyle(color: cloudMuted, height: 1.5),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _tab = 2),
          child: const Text('Visit your profile  →'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        ),
        const Text(
          'A good cloud is worth sharing.',
          style: TextStyle(
            fontFamily: 'Instrument Serif',
            fontSize: 27,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'A passing shape. An unexpected colour. Something only you noticed.',
          style: TextStyle(color: cloudMuted, height: 1.6),
        ),
        const SizedBox(height: 20),
        const Text(
          'Keep it kind. Post your own photos. Leave room for imagination.',
          style: TextStyle(color: cloudMuted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
  Widget _profileView() => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CloudAvatar(name: _name, data: _avatar, radius: 40),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(
                          fontFamily: 'Instrument Serif',
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_profile['bio'] as String? ?? '').isEmpty
                            ? 'A cloud watcher with a sky to share.'
                            : _profile['bio'] as String,
                        style: const TextStyle(color: cloudMuted, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loading ? null : _editProfile,
                        child: const Text('Edit profile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_loading || _error != null)
              _state()
            else
              ProfileGallery(
                posts: _own,
                hasMore: _ownNext != null,
                loadingMore: _more,
                onMore: () => _loadMore(true),
                onOpen: _detail,
                onPost: () => setState(() => _tab = 1),
              ),
          ],
        ),
      ),
    ),
  );
}

class CloudPost extends StatefulWidget {
  const CloudPost({
    super.key,
    required this.post,
    required this.own,
    required this.onLike,
    required this.onBest,
    required this.onDelete,
  });
  final CloudPhoto post;
  final bool own;
  final Future<void> Function() onLike, onBest;
  final VoidCallback onDelete;
  @override
  State<CloudPost> createState() => _CloudPostState();
}

class _CloudPostState extends State<CloudPost> {
  bool _busy = false;
  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final age = DateTime.now().difference(p.createdAt);
    final time = age.inDays > 0
        ? '${age.inDays}d ago'
        : age.inHours > 0
        ? '${age.inHours}h ago'
        : 'Just now';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CloudAvatar(name: p.name, data: p.avatar, radius: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      p.location.isEmpty ? time : '${p.location} · $time',
                      style: const TextStyle(fontSize: 12, color: cloudMuted),
                    ),
                  ],
                ),
              ),
              if (widget.own)
                PopupMenuButton<String>(
                  tooltip: 'Photo options',
                  onSelected: (_) => widget.onDelete(),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete photo'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 1.15,
            child: Semantics(
              label: p.caption,
              image: true,
              child: PhotoImage(p.image),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: p.liked ? 'Unlike cloud' : 'Like cloud',
              onPressed: _busy ? null : () => _act(widget.onLike),
              icon: Icon(
                p.liked ? Icons.favorite : Icons.favorite_border,
                color: p.liked ? const Color(0xFFAC4E58) : cloudInk,
              ),
            ),
            Text(
              '${p.likes} ${p.likes == 1 ? 'like' : 'likes'}',
              style: const TextStyle(fontSize: 13),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Copy caption',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${p.caption} — ${p.name}, Cloud Club'),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Caption copied.')),
                  );
                }
              },
              icon: const Icon(Icons.ios_share, size: 21),
            ),
            if (widget.own)
              IconButton(
                tooltip: p.best
                    ? 'Remove from best clouds'
                    : 'Add to best clouds',
                onPressed: _busy ? null : () => _act(widget.onBest),
                icon: Icon(p.best ? Icons.star : Icons.star_border, size: 23),
              ),
          ],
        ),
        Text(p.caption, style: const TextStyle(height: 1.6)),
      ],
    );
  }
}

class ProfileGallery extends StatefulWidget {
  const ProfileGallery({
    super.key,
    required this.posts,
    required this.onOpen,
    required this.onPost,
    required this.hasMore,
    required this.loadingMore,
    required this.onMore,
  });
  final List<CloudPhoto> posts;
  final ValueChanged<CloudPhoto> onOpen;
  final VoidCallback onPost, onMore;
  final bool hasMore, loadingMore;
  @override
  State<ProfileGallery> createState() => _ProfileGalleryState();
}

class _ProfileGalleryState extends State<ProfileGallery> {
  bool _best = true;
  @override
  Widget build(BuildContext context) {
    final posts = widget.posts.where((p) => !_best || p.best).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => setState(() => _best = true),
              child: Text(
                'Best clouds',
                style: TextStyle(
                  fontWeight: _best ? FontWeight.w600 : FontWeight.w400,
                  color: _best ? cloudInk : cloudMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _best = false),
              child: Text(
                'All clouds',
                style: TextStyle(
                  fontWeight: !_best ? FontWeight.w600 : FontWeight.w400,
                  color: !_best ? cloudInk : cloudMuted,
                ),
              ),
            ),
            Text(
              '${posts.length}${widget.hasMore ? '+' : ''} ${posts.length == 1 ? 'photo' : 'photos'}',
              style: const TextStyle(color: cloudMuted, fontSize: 12),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 16),
        if (posts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cloudGround,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  size: 48,
                  color: Color(0xFF8199A7),
                ),
                const SizedBox(height: 16),
                Text(
                  _best
                      ? 'Only the clouds you love most.'
                      : 'Your sky starts here.',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  _best ? 'Star one of your photos to give it a place here.' : 'Post your first photo and make this little corner yours.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: cloudMuted, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.posts.isEmpty
                      ? widget.onPost
                      : () => setState(() => _best = false),
                  child: Text(
                    widget.posts.isEmpty
                        ? 'Post a cloud →'
                        : 'See all your clouds →',
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: c.maxWidth < 450 ? 2 : 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) => Semantics(
                label: posts[i].caption,
                button: true,
                child: InkWell(
                  onTap: () => widget.onOpen(posts[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PhotoImage(posts[i].image),
                  ),
                ),
              ),
            ),
          ),
        if (widget.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: OutlinedButton(
              onPressed: widget.loadingMore ? null : widget.onMore,
              child: Text(
                widget.loadingMore ? 'Loading...' : 'Load older clouds',
              ),
            ),
          ),
      ],
    );
  }
}

class UploadCloud extends StatefulWidget {
  const UploadCloud({
    super.key,
    required this.picker,
    required this.api,
    required this.onPosted,
    required this.name,
    required this.avatar,
  });
  final Future<String?> Function() picker;
  final CloudApi api;
  final Future<void> Function() onPosted;
  final String name, avatar;
  @override
  State<UploadCloud> createState() => _UploadCloudState();
}

class _UploadCloudState extends State<UploadCloud> {
  final _caption = TextEditingController(), _location = TextEditingController();
  String? _photo, _error;
  bool _best = true, _busy = false, _picking = false;
  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final data = await widget.picker();
      if (mounted && data != null) setState(() => _photo = data);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not open this photo. Please try another.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _post() async {
    if (_busy) return;
    if (_photo == null || _caption.text.trim().isEmpty) {
      setState(
        () => _error = _photo == null
            ? 'Choose a cloud photo first.'
            : 'Add a caption for your cloud.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.request(
        '/posts',
        data: {
          'image': _photo,
          'caption': _caption.text.trim(),
          'location': _location.text.trim(),
          'best': _best,
        },
      );
      await widget.onPosted();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A little piece of your sky.',
              style: TextStyle(
                fontFamily: 'Instrument Serif',
                fontSize: 32,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The cloud you almost walked past. Share that one.',
              style: TextStyle(color: cloudMuted, height: 1.5),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, c) {
                final preview = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Material(
                        color: cloudGround,
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _busy || _picking ? null : _pick,
                          child: _photo == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 48,
                                      color: Color(0xFF8199A7),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      _picking
                                          ? 'Opening photos...'
                                          : 'Find your cloud',
                                      style: const TextStyle(fontSize: 21),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Choose a photo to get started',
                                      style: TextStyle(color: cloudMuted),
                                    ),
                                  ],
                                )
                              : PhotoImage(_photo!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'JPEG, PNG or WebP · Up to 5 MB',
                            style: TextStyle(color: cloudMuted, fontSize: 12),
                          ),
                        ),
                        if (_photo != null)
                          TextButton(
                            onPressed: _busy ? null : _pick,
                            child: const Text('Change photo'),
                          ),
                      ],
                    ),
                  ],
                );
                final form = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CloudAvatar(name: widget.name, data: widget.avatar),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                'Posting to the club',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cloudMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Caption',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _caption,
                      enabled: !_busy,
                      maxLength: 500,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'What do you see in this cloud?',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Location (optional)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _location,
                      enabled: !_busy,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        hintText: 'Somewhere under the sky',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'One of my best clouds',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Feature it on your profile.',
                        style: TextStyle(fontSize: 12, color: cloudMuted),
                      ),
                      value: _best,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _best = v),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy || _picking ? null : _post,
                      child: Text(_busy ? 'Sharing your sky...' : 'Post cloud'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your photo and caption will be visible to everyone in Cloud Club. Share only photos you took.',
                      style: TextStyle(
                        fontSize: 12,
                        color: cloudMuted,
                        height: 1.6,
                      ),
                    ),
                  ],
                );
                return c.maxWidth >= 640
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: preview),
                          const SizedBox(width: 32),
                          Expanded(child: form),
                        ],
                      )
                    : Column(
                        children: [preview, const SizedBox(height: 24), form],
                      );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.api,
    required this.profile,
    required this.picker,
  });
  final CloudApi api;
  final Map<String, dynamic> profile;
  final Future<String?> Function() picker;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final _name = TextEditingController(
    text: widget.profile['name'] as String,
  );
  late final _bio = TextEditingController(
    text: widget.profile['bio'] as String,
  );
  late String _avatar = widget.profile['avatar'] as String;
  String? _error;
  bool _busy = false, _picking = false;
  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final photo = await widget.picker();
      if (mounted && photo != null) setState(() => _avatar = photo);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open this photo.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.request(
        '/profile',
        data: {
          'name': _name.text.trim(),
          'bio': _bio.text.trim(),
          'avatar': _avatar,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Your little corner'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CloudAvatar(name: _name.text, data: _avatar, radius: 38),
              ),
              TextButton(
                onPressed: _busy || _picking ? null : _pick,
                child: Text(
                  _picking ? 'Opening photos...' : 'Change profile photo',
                ),
              ),
              if (_avatar.isNotEmpty)
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _avatar = ''),
                  child: const Text('Remove profile photo'),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: !_busy,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bio,
                enabled: !_busy,
                maxLength: 160,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'A little about you and your sky.',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _picking ? null : _save,
          child: Text(_busy ? 'Saving...' : 'Save profile'),
        ),
      ],
    ),
  );
}
