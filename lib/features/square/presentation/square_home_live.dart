part of 'square_page.dart';

class SquareHome extends StatelessWidget {
  const SquareHome({required this.onLive, super.key});

  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
    children: [
      const _TopActions(),
      const SizedBox(height: 22),
      Row(
        children: [
          Transform.translate(
            offset: const Offset(0, -1),
            child: const ClipOval(
              child: Image(
                image: AssetImage('assets/images/avatar_design.png'),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: AcoInput(
              hint: '搜索帖文或消息',
              trailing: const Icon(CupertinoIcons.add, color: _black, size: 21),
              onTrailingTap: () => _showComposer(context),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Transform.translate(
        offset: const Offset(1, 0),
        child: _SquareTabs(onLive: onLive),
      ),
      const SizedBox(height: 700),
    ],
  );
}

class LivePage extends StatefulWidget {
  const LivePage({this.onNav, super.key});

  final ValueChanged<int>? onNav;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final AccountApiClient _apiClient = AccountApiClient();
  late Future<List<LiveSession>> _lives;

  @override
  void initState() {
    super.initState();
    _lives = _loadLives();
  }

  Future<List<LiveSession>> _loadLives() =>
      AccountSession(_apiClient).listLives();

  void _retry() => setState(() => _lives = _loadLives());

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: _black,
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _IconButton(
                      icon: CupertinoIcons.back,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const _TopActions(),
                  ],
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    '正在进行',
                    style: TextStyle(
                      color: _white,
                      fontSize: AcoTypography.titleLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FutureBuilder<List<LiveSession>>(
                  future: _lives,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(child: CupertinoActivityIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _LiveListState(
                        message: '会议列表加载失败，请检查网络后重试。',
                        actionLabel: '重试',
                        onPressed: _retry,
                      );
                    }
                    final sessions = snapshot.data ?? const <LiveSession>[];
                    if (sessions.isEmpty) {
                      return const _LiveListState(message: '暂无会议');
                    }
                    return Column(
                      children: [
                        for (final session in sessions) ...[
                          _LiveItem(session: session),
                          const SizedBox(height: 28),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          BottomNav(
            selected: 3,
            onSelected: (value) {
              if (value != 3) {
                widget.onNav?.call(value);
                if (widget.onNav == null) Navigator.of(context).maybePop();
              }
            },
          ),
        ],
      ),
    ),
  );
}

/*
class _SquareTabs extends StatelessWidget {
  const _SquareTabs({required this.onLive});

  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(
        width: 50,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '推荐',
              style: TextStyle(
                color: _white,
                fontSize: AcoTypography.body,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 8),
            _DownMark(),
          ],
        ),
      ),
      const SizedBox(width: 45),
      const SizedBox(
        width: 68,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '好友',
              style: TextStyle(color: _muted, fontSize: AcoTypography.body),
            ),
            SizedBox(width: 4),
            _CountBadge(),
          ],
        ),
      ),
      const SizedBox(width: 26),
      GestureDetector(
        onTap: onLive,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 34,
          child: Text(
            '会议',
            style: TextStyle(color: _muted, fontSize: AcoTypography.body),
          ),
        ),
      ),
    ],
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(1, 1),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _lime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '77',
        style: TextStyle(color: _black, fontSize: AcoTypography.caption),
      ),
    ),
  );
}

class _DownMark extends StatelessWidget {
  const _DownMark();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(10, 7), painter: _DownMarkPainter());
}

class _DownMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = _lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LiveItem extends StatelessWidget {
  const _LiveItem({required this.session});

  final LiveSession session;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(CupertinoIcons.video_camera_solid, color: _lime, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              session.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _white,
                fontSize: AcoTypography.bodySmall,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (session.coverUrl.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.network(
            _liveCoverUrl(session.coverUrl),
            height: 155,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 155,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
    ],
  );
}

String _liveCoverUrl(String coverUrl) {
  if (Uri.tryParse(coverUrl)?.hasScheme ?? false) return coverUrl;
  final apiUri = Uri.parse(const AppConfig().apiBaseUrl);
  return apiUri.replace(path: coverUrl).toString();
}

class _LiveListState extends StatelessWidget {
  const _LiveListState({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        const Icon(CupertinoIcons.video_camera, color: _muted, size: 32),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(color: _muted, fontSize: AcoTypography.body),
        ),
        if (actionLabel != null)
          CupertinoButton(onPressed: onPressed, child: Text(actionLabel!)),
      ],
    ),
  );
}
*/
