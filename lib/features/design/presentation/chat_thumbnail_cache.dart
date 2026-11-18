part of 'aco_design_shell.dart';

class _CachedChatThumbnail extends StatefulWidget {
  const _CachedChatThumbnail({
    required this.url,
    required this.palette,
    this.kind = 'thumbnail',
    this.originalUrl,
  });

  final String url;
  final String kind;
  final String? originalUrl;
  final AcoPalette palette;

  @override
  State<_CachedChatThumbnail> createState() => _CachedChatThumbnailState();
}

class _CachedChatThumbnailState extends State<_CachedChatThumbnail> {
  late Future<File> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _ChatMediaCache.load(
      widget.url,
      kind: widget.kind,
      originalUrl: widget.originalUrl,
    );
  }

  @override
  void didUpdateWidget(covariant _CachedChatThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url &&
        oldWidget.kind == widget.kind &&
        oldWidget.originalUrl == widget.originalUrl)
      return;
    _thumbnail = _ChatMediaCache.load(
      widget.url,
      kind: widget.kind,
      originalUrl: widget.originalUrl,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: _thumbnail,
    builder: (context, snapshot) {
      final file = snapshot.data;
      if (file != null) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stackTrace) =>
              _ImageUnavailable(palette: widget.palette),
        );
      }
      if (snapshot.hasError) {
        return _ImageUnavailable(palette: widget.palette);
      }
      return const SizedBox(
        width: 64,
        height: 64,
        child: Center(child: CupertinoActivityIndicator()),
      );
    },
  );
}
