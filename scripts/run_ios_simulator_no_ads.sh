#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ "$#" -eq 0 ]; then
  echo "用法：$0 <模拟器 UDID> [flutter run 参数...]" >&2
  exit 2
fi
SIMULATOR_ID="$1"
shift
declare -a FLUTTER_RUN_ARGS=()
declare -a USER_DART_DEFINES=()
while (($#)); do
  case "$1" in
    --dart-define=*) USER_DART_DEFINES+=("${1#--dart-define=}") ;;
    --dart-define)
      (($# >= 2)) || { echo "--dart-define 后缺少 KEY=VALUE" >&2; exit 2; }
      shift
      USER_DART_DEFINES+=("$1")
      ;;
    *) FLUTTER_RUN_ARGS+=("$1") ;;
  esac
  shift
done
export SIMULATOR_DART_DEFINES="$(printf '%s\n' "${USER_DART_DEFINES[@]}")"

flutter pub get

BACKUP_DIR="$(mktemp -d)"
cp .flutter-plugins-dependencies "$BACKUP_DIR/plugins.json"
cp ios/Flutter/Generated.xcconfig "$BACKUP_DIR/Generated.xcconfig"
cp ios/Runner/GeneratedPluginRegistrant.m "$BACKUP_DIR/GeneratedPluginRegistrant.m"
cp ios/Runner.xcodeproj/project.pbxproj "$BACKUP_DIR/project.pbxproj"

restore_project() {
  local status=$?
  trap - EXIT INT TERM
  cp "$BACKUP_DIR/plugins.json" .flutter-plugins-dependencies
  cp "$BACKUP_DIR/Generated.xcconfig" ios/Flutter/Generated.xcconfig
  cp "$BACKUP_DIR/GeneratedPluginRegistrant.m" ios/Runner/GeneratedPluginRegistrant.m
  cp "$BACKUP_DIR/project.pbxproj" ios/Runner.xcodeproj/project.pbxproj
  if ! (cd ios && pod install); then
    echo "警告：恢复广告 Pods 失败，请在 ios 目录执行 pod install。" >&2
  fi
  rm -rf "$BACKUP_DIR"
  exit "$status"
}
trap restore_project EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

python3 - <<'PY'
import json
import base64
import os
import re
from pathlib import Path

omitted_plugins = {
    'huijing_ads_plugin',
    'flutter_livepush_plugin',
    'flutter_aliplayer',
}
plugins_path = Path('.flutter-plugins-dependencies')
plugins = json.loads(plugins_path.read_text())
ios_plugins = plugins.get('plugins', {}).get('ios', [])
filtered = [plugin for plugin in ios_plugins if plugin.get('name') not in omitted_plugins]
if len(filtered) == len(ios_plugins):
    raise SystemExit('未找到预期的 iOS 原生插件，停止以免误改 Pods 配置。')
plugins['plugins']['ios'] = filtered
plugins_path.write_text(json.dumps(plugins, ensure_ascii=False))

registrant_path = Path('ios/Runner/GeneratedPluginRegistrant.m')
registrant = registrant_path.read_text()
for plugin, header, klass in (
    ('huijing_ads_plugin', 'HuijingAdsPlugin', 'HuijingAdsPlugin'),
    ('flutter_livepush_plugin', 'LivePushPlugin', 'LivePushPlugin'),
    ('flutter_aliplayer', 'FlutterAliplayerPlugin', 'FlutterAliplayerPlugin'),
):
    registrant, import_count = re.subn(
        rf'#if __has_include\(<{plugin}/{header}\.h>\)\n'
        rf'#import <{plugin}/{header}\.h>\n'
        rf'#else\n@import {plugin};\n#endif\n\n',
        '',
        registrant,
    )
    registrant, register_count = re.subn(
        rf'^\s*\[{klass} registerWithRegistrar:.*\];\n',
        '',
        registrant,
        flags=re.MULTILINE,
    )
    if import_count != 1 or register_count != 1:
        raise SystemExit(f'无法安全移除 {plugin} 注册，已停止。')
registrant_path.write_text(registrant)

xcconfig_path = Path('ios/Flutter/Generated.xcconfig')
xcconfig = xcconfig_path.read_text()
xcconfig = re.sub(
    r'(?m)^(EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]=[^\n]*)\s+arm64\b',
    lambda match: ' '.join(match.group(1).split()),
    xcconfig,
)
simulator_defines = (
    base64.b64encode(b'ACO_SKIP_ADS=true').decode(),
    base64.b64encode(b'ACO_SKIP_NATIVE_LIVE=true').decode(),
)
user_defines = tuple(
    base64.b64encode(value.encode()).decode()
    for value in os.environ.get('SIMULATOR_DART_DEFINES', '').splitlines()
    if value
)
defines = re.search(r'(?m)^DART_DEFINES=(.*)$', xcconfig)
if defines:
    values = defines.group(1).split(',')
    values.extend(
        value for value in (*simulator_defines, *user_defines) if value not in values
    )
    xcconfig = xcconfig[:defines.start(1)] + ','.join(values) + xcconfig[defines.end(1):]
else:
    xcconfig += f'\nDART_DEFINES={",".join((*simulator_defines, *user_defines))}\n'
xcconfig_path.write_text(xcconfig)

project_path = Path('ios/Runner.xcodeproj/project.pbxproj')
project = project_path.read_text()
for entry in (
    '\t\t\t\t79ED32AA5DDE0434219568B6 /* AcoScreenBroadcast.appex in Embed App Extensions */,\n',
    '\t\t\t\t51B682ED7D3878AC92DEAC47 /* PBXTargetDependency */,\n',
    '\t\t\t\t8BFC217140321896AD501CD2 /* AlivcLibReplayKitExt.framework in Frameworks */,\n',
    '\t\t\t\t0AD49D12B694A8D01D32783D /* AlivcLibReplayKitExt.framework in Frameworks */,\n',
):
    count = project.count(entry)
    if count > 1:
        raise SystemExit('无法安全禁用模拟器不支持的直播扩展，已停止。')
    if count == 1:
        project = project.replace(entry, '', 1)
project_path.write_text(project)

PY

(cd ios && pod install)

python3 - <<'PY'
import re
from pathlib import Path

for pod_config in Path('ios/Pods/Target Support Files').rglob('*.xcconfig'):
    settings = pod_config.read_text()
    settings = re.sub(
        r'(?m)^EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]\s*=\s*[^\n]*\barm64\b[^\n]*\n',
        '',
        settings,
    )
    settings = re.sub(
        r'(?m)^VALID_ARCHS\[sdk=iphonesimulator\*\]\s*=\s*x86_64\s*\n',
        '',
        settings,
    )
    pod_config.write_text(settings)
PY

APP_PATH="$BACKUP_DIR/DerivedData/Build/Products/Debug-iphonesimulator/Runner.app"
if ! xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$BACKUP_DIR/DerivedData" \
  -clonedSourcePackagesDirPath "$BACKUP_DIR/SourcePackages" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=- \
  build >"$BACKUP_DIR/xcodebuild.log" 2>&1; then
  cp "$BACKUP_DIR/xcodebuild.log" /tmp/aco-chat-ios-simulator-xcodebuild.log
  rg -n -C 2 'error:|fatal error|BUILD FAILED|SwiftCompile normal' \
    "$BACKUP_DIR/xcodebuild.log" | tail -100 || true
  exit 1
fi

if ((${#FLUTTER_RUN_ARGS[@]})); then
  flutter run --no-pub --use-application-binary="$APP_PATH" -d "$SIMULATOR_ID" "${FLUTTER_RUN_ARGS[@]}"
else
  flutter run --no-pub --use-application-binary="$APP_PATH" -d "$SIMULATOR_ID"
fi
