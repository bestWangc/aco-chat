#!/bin/sh
set -eu

license_dir="${SRCROOT}/../aliyun_license/ios"
destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

certificate=$(find "$license_dir" -maxdepth 1 -type f -name 'AliVideoCert-*.crt' -print -quit 2>/dev/null || true)
if [ -n "$certificate" ]; then
  cp "$certificate" "$destination/AliVideoCert.crt"
else
  echo "warning: iOS Aliyun license certificate not found in $license_dir"
fi

license_config="$license_dir/license.xcconfig"
license_key=$(sed -nE 's/^[[:space:]]*ALIVC_LICENSE_KEY_CN[[:space:]]*=[[:space:]]*(.*)$/\1/p' "$license_config" 2>/dev/null | head -n 1 | tr -d '\r\n')
if [ -n "$license_key" ] && [ -f "$destination/Info.plist" ]; then
  if /usr/libexec/PlistBuddy -c 'Print :AlivcLicenseKey_CN' "$destination/Info.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :AlivcLicenseKey_CN $license_key" "$destination/Info.plist"
  else
    /usr/libexec/PlistBuddy -c "Add :AlivcLicenseKey_CN string $license_key" "$destination/Info.plist"
  fi
else
  echo "warning: iOS Aliyun license key not found in $license_config"
fi
