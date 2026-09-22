import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

class AcoNetworkImage extends StatelessWidget {
  const AcoNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.memCacheWidth,
    this.memCacheHeight,
    this.semanticLabel,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? semanticLabel;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: placeholder ?? _emptyPlaceholder,
      errorWidget: errorWidget ?? _emptyError,
    );
    if (semanticLabel == null) return image;
    return Semantics(image: true, label: semanticLabel, child: image);
  }

  Widget _emptyPlaceholder(BuildContext context, String url) =>
      SizedBox(width: width, height: height);

  Widget _emptyError(BuildContext context, String url, Object error) =>
      SizedBox(width: width, height: height);
}
