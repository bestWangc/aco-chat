import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

enum AlivcPusherPreviewType {
  base,
  push,
  play,
}

typedef void AlivcPusherPreviewCreatedCallback(id);

/// 创建预览视图
///
/// [onCreated] 视图创建回调
///
/// [x] 视图frame x轴起始点
///
/// [y] 视图frame y轴起始点
///
/// [width] 视图frame宽
///
/// [height] 视图frame高
class AlivcPusherPreview extends StatefulWidget {
  final AlivcPusherPreviewType viewType;
  final AlivcPusherPreviewCreatedCallback? onCreated;
  final x;
  final y;
  final width;
  final height;

  AlivcPusherPreview({
    Key? key,
    @required required this.viewType,
    @required required this.onCreated,
    @required this.x,
    @required this.y,
    @required this.width,
    @required this.height,
  });

  @override
  State<StatefulWidget> createState() => _PusherPreviewState();
}

class _PusherPreviewState extends State<AlivcPusherPreview> {
  static const String _livePusherPreviewName = "plugins.livepush.preview";
  static const String _livePlayerViewName = "plugins.liveplayer.view";
  static const String _livePusherBasePreviewName =
      "plugins.livepush.base.preview";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _nativeView();
  }

  _nativeView() {
    String viewTypeStr = "";
    if (widget.viewType == AlivcPusherPreviewType.push) {
      viewTypeStr = _livePusherPreviewName;
    } else if (widget.viewType == AlivcPusherPreviewType.play) {
      viewTypeStr = _livePlayerViewName;
    } else {
      viewTypeStr = _livePusherBasePreviewName;
    }

    if (Platform.isAndroid) {
      return AndroidView(
        viewType: viewTypeStr,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: <String, dynamic>{
          "x": widget.x,
          "y": widget.y,
          "width": widget.width,
          "height": widget.height,
          "viewType": viewTypeStr,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return UiKitView(
        viewType: viewTypeStr,
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: <String, dynamic>{
          "x": widget.x,
          "y": widget.y,
          "width": widget.width,
          "height": widget.height,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
  }

  Future<void> _onPlatformViewCreated(id) async {
    if (widget.onCreated != null) {
      widget.onCreated!(id);
    }
  }
}
