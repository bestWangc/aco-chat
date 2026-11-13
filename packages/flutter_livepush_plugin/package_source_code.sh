#!/bin/bash
#
# package_source_code.sh
#
# Created by baorunchen on 2024/06/23
# Copyright © 2024 Alibaba Cloud. All rights reserved.
#
set -e

# 定义常量
# Defining constants
DST_FOLDER_NAME="flutter_livepush_plugin"
OUT_FOLDER_NAME="outZip"
SRC_PATH=$(pwd)
DST_PATH="$SRC_PATH/$DST_FOLDER_NAME"
OUT_PATH="$SRC_PATH/$OUT_FOLDER_NAME/$DST_FOLDER_NAME.zip"

# 定义要忽略的文件和文件夹
# Defining the list of files and folders to ignore
exclude_list=(
  ".git"
  ".aoneci"
  ".gitmodules"
  ".DS_Store"
  ".idea"
  ".vscode"
  ".dart_tool"
  ".gradle"
  "build"
  "doc"
  "local.properties"
  "**.log"
  "commits.json"
  "**.sh"
  "**.py"
  "Build"
  "Pods"
  "DerivedData"
  ".metadata"
  ".symlinks"
  "**.lock"
  "**.dSYM"
  "**.ipa"
  "**.xcworkspace"
  "**.xcuserstate"
  ".flutter-plugins"
  ".flutter-plugins-dependencies"
  "$DST_FOLDER_NAME"
  "$OUT_FOLDER_NAME"
)

# 定义要剔除的测试代码字符串列表
# Defining the list of strings to remove from test code
exclude_test_code=(
  "//内部调试代码，发布删除 -- 注释勿动"
)

# 显示用法信息
# Showing usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  -h, --help            Show this help message and exit"
  echo "  -s, --source PATH     Set the source path (default: current directory)"
  echo "  -d, --dst-folder NAME Set the destination folder name (default: $DST_FOLDER_NAME)"
  echo "  -o, --out-folder NAME Set the output folder name (default: $OUT_FOLDER_NAME)"
  echo
}

# 日志函数
# Log function
log() {
  echo "[BUILD-FLUTTER] [$(date +'%Y/%m/%d %H:%M:%S')]: ${1}"
}

# 删除测试代码
# Remove test code
removeTestCode() {
  local projectPath="$1"
  log "Removing test code from $projectPath"

  # 构建正则表达式模式
  # Building the regular expression pattern
  local pattern=""
  for tag in "${exclude_test_code[@]}"; do
    if [[ -z "$pattern" ]]; then
      pattern="$(printf '%s' "$tag" | sed 's/[.[\*^$(){}+?\/\\|]/\\&/g')"
    else
      pattern="${pattern}|$(printf '%s' "$tag" | sed 's/[.[\*^$(){}+?\/\\|]/\\&/g')"
    fi
  done
  log "Using pattern: $pattern"

  # 遍历所有文件并处理
  # Traverse all files and handle them
  find "$projectPath" -type f | while read -r file; do
    if grep -qE "$pattern" "$file"; then
      if [[ "$(uname)" == 'Darwin' ]]; then
        sed -E -i '' "/$pattern/d" "$file"
      elif [[ "$(uname)" == 'Linux' ]]; then
        sed -E -i "/$pattern/d" "$file"
      fi
    fi
  done
}

# 生成 rsync 排除参数
# Generating rsync exclude parameters
generateRsyncExclude() {
  local rsync_exclude=""
  for exclude in "${exclude_list[@]}"; do
    rsync_exclude+="--exclude=${exclude} "
  done
  echo "$rsync_exclude"
}

# 复制模块
# Copy module
copyModule() {
  # 生成 rsync 排除参数
  # Generating rsync exclude parameters
  local rsync_exclude
  rsync_exclude=$(generateRsyncExclude)

  log "Starting file copy with rsync excludes: $rsync_exclude"

  # 复制文件
  # Copy files
  if ! rsync -av $rsync_exclude "$SRC_PATH/" "$DST_PATH/"; then
    log "Error during rsync operation. Some files might not have been transferred. See details below:"
    rsync -av --dry-run $rsync_exclude "$SRC_PATH/" "$DST_PATH/"
    exit 1
  fi

  # 检查 rsync 是否执行成功
  # Check if rsync executed successfully
  if [ $? -ne 0 ]; then
    log "Error during rsync operation"
    exit 1
  fi
}

# 压缩目录到 zip 文件
# Compress directory to zip file
compress() {
  local srcPath="$1"
  local dstPath="$2"

  if [ ! -d "$srcPath" ]; then
    log "Source path '$srcPath' does not exist!"
    exit 1
  fi

  mkdir -p "$(dirname "$dstPath")"
  log "Compressing $srcPath to $dstPath"

  (cd "$srcPath" && zip -r "$dstPath" .)

  if [ $? -ne 0 ]; then
    log "Error during compression"
    exit 1
  fi
}

# 处理命令行参数
# Handle command-line arguments
handle_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -s | --source)
      SRC_PATH="$2"
      shift
      ;;
    -d | --dst-folder)
      DST_FOLDER_NAME="$2"
      DST_PATH="$SRC_PATH/$DST_FOLDER_NAME"
      shift
      ;;
    -o | --out-folder)
      OUT_FOLDER_NAME="$2"
      OUT_PATH="$SRC_PATH/$OUT_FOLDER_NAME/$DST_FOLDER_NAME.zip"
      shift
      ;;
    *)
      log "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done
}

# 主流程
# Main flow
main() {
  handle_args "$@"

  log "*************** Build process started *****************"

  # 清理之前生成的文件
  # Clean up previously generated files
  rm -rf "$DST_PATH"
  rm -rf "$OUT_PATH"
  log "Clean up finished"

  copyModule
  log "File copy finished"

  removeTestCode "$DST_PATH"
  log "Test code removal finished"

  compress "$DST_PATH" "$OUT_PATH"
  log "Compression finished"

  log "*************** Build process completed *****************"
}

# 执行主流程
# Execute main flow
main "$@"
