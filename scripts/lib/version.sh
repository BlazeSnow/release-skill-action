# 版本号解析（由 release-skill.sh source）

# $1=BASE 目录 $2=tag 输入（已回退到 ref 名）；结果写入全局 VERSION
resolve_version() {
  local base="$1" tag="$2"
  VERSION=''
  if [ -f "$base/VERSION" ]; then
    VERSION="$(head -n 1 "$base/VERSION" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    log "版本号来源: BASE 目录 VERSION 文件 -> $VERSION"
  fi
  if [ -z "$VERSION" ]; then
    [ -n "$tag" ] || die '无法确定版本号: BASE 目录无 VERSION 文件，且未提供 tag 输入或 tag ref'
    VERSION="$tag"
    log "版本号来源: tag/ref -> $VERSION"
  fi
  [ -n "$VERSION" ] || die '版本号为空'
  case "$VERSION" in
    */*) die "版本号不允许包含 /: $VERSION" ;;
  esac
}
