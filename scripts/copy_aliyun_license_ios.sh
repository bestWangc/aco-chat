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
