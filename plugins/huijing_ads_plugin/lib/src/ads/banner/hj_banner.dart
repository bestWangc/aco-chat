import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huijing_ads_plugin/huijing_ads_plugin.dart';

class HjBannerAd with HjAdEventHandler {
  static const MethodChannel _channel = MethodChannel('com.huijingads/banner');

  final HjAdRequest request;
  final bool animated;
  late String _uniqId;
  late MethodChannel _adChannel;
  final double width; //广告宽度
  final double height;
  late final HjBannerListener<HjBannerAd> _listener;
  Size? adSize;
  HjBannerAd({
    Key? key,
    required this.request,
    required this.width,
    required this.height,
    required HjBannerListener<HjBannerAd> listener,
    this.animated = true,
  }) : super() {
    _uniqId = hashCode.toString();
    _listener = listener;
    delegate = IHjBannerListener(this, _listener);
    _adChannel = MethodChannel('com.huijingads/banner.$_uniqId');
    _adChannel.setMethodCallHandler(handleEvent);
  }

  void updateAdSize(Size size) {
    adSize = size;
  }

  Size? getAdSize() {
    return adSize;
  }

  Future<bool> isReady() async {
    bool isReady = await _channel.invokeMethod('isReady', {
      "uniqId": _uniqId,
    });
    return isReady;
  }

  Future<void> loadAd() async {
    await _channel.invokeMethod('load', {
      "uniqId": _uniqId,
      "width": width,
      "height": height,
      'request': request.toJson()
    });
  }

  Future<void> destroy() async {
    await _channel.invokeMethod('destroy', {"uniqId": _uniqId});
  }
// Banner广告刷新动画，默认值：false
}

class BannerAdWidget extends StatefulWidget {
  @override
  BannerAdWidgetState createState() => BannerAdWidgetState();

  final HjBannerAd hjBannerAd;
  late final ValueNotifier<Size> sizeNotify;

  BannerAdWidget({
    Key? key,
    required this.hjBannerAd,
    required double width,
    required double height,
  }) : super(key: key) {
    sizeNotify = ValueNotifier<Size>(Size(width, height));
  }

  void updateAdSize(Size size) {
    if (size.height > 0 && size.width > 0) {
      sizeNotify.value = size;
    }
  }
}

class BannerAdWidgetState extends State<BannerAdWidget>
    with AutomaticKeepAliveClientMixin {
  // View 类型
  final String viewType = 'flutter_hj_ads_banner';

  // 创建参数
  late Map<String, dynamic> creationParams;

  BannerAdWidgetState() : super() {}

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (Platform.isIOS) {
      return _buildIosWidget();
    } else {
      return _buildAndroidWidget();
    }
  }

  Widget _buildIosWidget() {
    return ValueListenableBuilder<Size>(
      builder: (ctx, size, child) {
        return SizedBox.fromSize(
          size: size,
          child: child,
        );
      },
      valueListenable: widget.sizeNotify,
      child: _buildUIKitView(),
    );
  }

  Widget _buildAndroidWidget() {
    return ValueListenableBuilder<Size>(
      builder: (ctx, size, child) {
        Size optSize = size;

        if (optSize.height < 1) {
          optSize = Size(size.width, 1);
        }
        return SizedBox.fromSize(
          size: optSize,
          child: child,
        );
      },
      valueListenable: widget.sizeNotify,
      child: _buildAndroidView(),
    );
  }

  _buildAndroidView() {
    return AndroidView(
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  _buildUIKitView() {
    return UiKitView(
      viewType: viewType,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  @override
  void initState() {
    super.initState();
    creationParams = <String, dynamic>{
      "uniqId": widget.hjBannerAd.hashCode.toString()
    };
  }

  @override
  void dispose() {
    super.dispose();
    widget.sizeNotify.dispose();
  }

  @override
  bool get wantKeepAlive => false;
}
