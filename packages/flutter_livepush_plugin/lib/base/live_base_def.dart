///
/// Copyright © 2023 Alibaba Cloud. All rights reserved.
///
/// Author：keria
/// Date：2023/12/11
/// Email：runchen.brc@alibaba-inc.com
///
/// Reference：Explain the purpose of the current file
///

import 'package:flutter/foundation.dart';

typedef OnLicenceCheck = void Function(
  AlivcLiveLicenseCheckResultCode result,
  String reason,
);

class AlivcLiveBaseListener {
  AlivcLiveBaseListener({
    @required this.onLicenceCheck,
  });

  final OnLicenceCheck? onLicenceCheck;
}

/// SDK License 校验枚举
///
/// [success] SDK校验license成功，可使用SDK功能
///
/// [invalid] licenseFile证书非法
///
/// [certExpired] licenseFile证书过期
///
/// [licenseExpired] licenseKey过期
///
/// [appIdInvalid] APPID非法
///
/// [licenseError] license错误，license key或者 license file 非法
///
/// [businessInvalid] 无效的业务信息
///
/// [platformInvalid] 该平台未购买
///
/// [uninitialized] 未初始化
enum AlivcLiveLicenseCheckResultCode {
  success,
  invalid,
  certExpired,
  licenseExpired,
  appIdInvalid,
  licenseError,
  businessInvalid,
  platformInvalid,
  uninitialized,
}

/// SDK log级别
///
/// [all] 全部
///
/// [verbose] 冗长
///
/// [debug] 调试
///
/// [info] 提示
///
/// [warn] 警告
///
/// [error] 错误
///
/// [none] 不输出日志
enum AlivcLivePushLogLevel {
  all,
  verbose,
  debug,
  info,
  warn,
  error,
  none,
}
