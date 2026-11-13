///
/// Copyright © 2023 Alibaba Cloud. All rights reserved.
///
/// Author：keria
/// Date：2023/12/12
/// Email：runchen.brc@alibaba-inc.com
///
/// Reference：Explain the purpose of the current file
///

/// 网络质量
///
/// [excellent] 网络极好，流程度清晰度质量好
///
/// [good] 网络好，流畅度清晰度和极好差不多
///
/// [poor] 网络较差，音视频流畅度清晰度有瑕疵，不影响沟通
///
/// [bad] 网络差，视频卡顿严重，音频能正常沟通
///
/// [veryBad] 网络极差，基本无法沟通
///
/// [disconnect] 网络中断
///
/// [unknown] 未知
enum AlivcLiveNetworkQuality {
  excellent,
  good,
  poor,
  bad,
  veryBad,
  disconnect,
  unknown,
}
