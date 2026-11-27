///
/// Copyright © 2023 Alibaba Cloud. All rights reserved.
///
/// Author：keria
/// Date：2023/12/11
/// Email：runchen.brc@alibaba-inc.com
///
/// Reference：Explain the purpose of the current file
///

wrapArgs({arg = ''}) {
  return {
    "arg": arg,
  };
}

/// bool值转String
///
/// [value] bool值
///
/// [returns] String值
String boolToString(bool value) {
  return (value == true ? 1 : 0).toString();
}

/// String值转bool
///
/// [value] String值
///
/// [returns] bool值
bool intToBool(int value) {
  return value == 1 ? true : false;
}
