#!/usr/bin/env bash
# 将 Skill 按白名单打包为 zip 并上传至 GitHub Release（由 composite action 调用）
set -euo pipefail

PREFIX='[release-skill]'
log() { printf '%s %s\n' "$PREFIX" "$*"; }
die() { printf '%s 错误: %s\n' "$PREFIX" "$*" >&2; exit 1; }

# 复合动作的 input 通过 INPUT_<大写名称> 环境变量传入（连字符保留，只能用 printenv 读取）
get_input() { printenv "INPUT_$1" 2>/dev/null | tr -d '\r' || true; }

find_python() { command -v python3 || command -v python; }

SKILL_NAME="$(get_input 'SKILL-NAME')"
SKILL_LOWER="$(get_input 'SKILL-LOWER-NAME')"
BASE_DIR_INPUT="$(get_input 'BASE-DIR')"
EXTRA_FILES_INPUT="$(get_input 'EXTRA-FILES')"
TAG_INPUT="$(get_input 'TAG')"
TOKEN_INPUT="$(get_input 'TOKEN')"

REF_NAME="${GITHUB_REF_NAME:-}"
REPO_ROOT="${GITHUB_WORKSPACE:-$PWD}"

[ -n "$SKILL_NAME" ] || die '缺少输入: skill-name'
[ -n "$SKILL_LOWER" ] || die '缺少输入: skill-lower-name'
[ -n "$BASE_DIR_INPUT" ] || die '缺少输入: base-dir'

case "$SKILL_NAME" in
  -*|*/*) die "skill-name 不允许以 - 开头或包含 /: $SKILL_NAME" ;;
esac
case "$SKILL_LOWER" in
  ''|.|..|*/*|*[[:space:]]*) die "skill-lower-name 须为不含空格与路径分隔符的名称: $SKILL_LOWER" ;;
esac
[ "$SKILL_LOWER" = "${SKILL_LOWER,,}" ] || die "skill-lower-name 必须全小写: $SKILL_LOWER"

case "$BASE_DIR_INPUT" in
  /*|[A-Za-z]:[\\/]*) BASE_DIR="$BASE_DIR_INPUT" ;;
  *) BASE_DIR="$REPO_ROOT/$BASE_DIR_INPUT" ;;
esac
BASE_DIR="${BASE_DIR%/}"
[ -d "$BASE_DIR" ] || die "BASE 目录不存在: $BASE_DIR"

log "Skill: $SKILL_NAME（部署名: $SKILL_LOWER）"
log "BASE 目录: $BASE_DIR"

# ---------- 1. 复制白名单到 dist/<小写名称> ----------
DIST_DIR="$REPO_ROOT/dist"
LOWER_DIR="$DIST_DIR/$SKILL_LOWER"
rm -rf "$LOWER_DIR"
mkdir -p "$LOWER_DIR"

copy_item() { # $1=相对路径 $2=required|optional
  local rel="$1" required="$2"
  local src="$BASE_DIR/$rel" dest="$LOWER_DIR/$rel"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    log "已复制: $rel"
  elif [ "$required" = required ]; then
    die "白名单必需项缺失: $rel（BASE 目录中未找到）"
  else
    log "可选项缺失，跳过: $rel"
  fi
}

log '复制白名单文件:'
copy_item 'SKILL.md' required
copy_item 'references' required
copy_item 'scripts' required
copy_item 'CHANGELOG.md' optional
copy_item 'LICENSE' optional
copy_item 'README.md' optional
copy_item 'VERSION' optional

# 额外文件或文件夹：每行一个，相对 BASE 目录，支持 # 注释
while IFS= read -r line; do
  entry="${line%%#*}"
  entry="${entry#"${entry%%[![:space:]]*}"}"
  entry="${entry%"${entry##*[![:space:]]}"}"
  [ -n "$entry" ] || continue
  case "$entry" in
    ..|../*|*/..|*/../*) die "extra-files 不允许包含上级路径: $entry" ;;
  esac
  copy_item "$entry" required
done <<< "$EXTRA_FILES_INPUT"

# ---------- 2. 确定版本号：VERSION 文件 > tag 输入 > 当前 ref 名 ----------
VERSION=''
if [ -f "$BASE_DIR/VERSION" ]; then
  VERSION="$(head -n 1 "$BASE_DIR/VERSION" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  log "版本号来源: BASE 目录 VERSION 文件 -> $VERSION"
fi
TAG="$TAG_INPUT"
[ -n "$TAG" ] || TAG="$REF_NAME"
if [ -z "$VERSION" ]; then
  [ -n "$TAG" ] || die '无法确定版本号: BASE 目录无 VERSION 文件，且未提供 tag 输入或 tag ref'
  VERSION="$TAG"
  log "版本号来源: tag/ref -> $VERSION"
fi
[ -n "$VERSION" ] || die '版本号为空'
case "$VERSION" in
  */*) die "版本号不允许包含 /: $VERSION" ;;
esac

# ---------- 3. 以 <小写名称> 为根目录打包 zip ----------
ZIP_NAME="${SKILL_NAME}-Skill-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"

PY="$(find_python || true)"
PACKER="${RELEASE_SKILL_PACKER:-auto}"
if [ "$PACKER" = auto ]; then
  if command -v zip >/dev/null 2>&1; then
    PACKER=zip
  elif [ -n "$PY" ]; then
    PACKER=python
  else
    die '未找到可用的打包工具（zip 或 python）'
  fi
fi

log "打包（$PACKER）: $ZIP_NAME"
case "$PACKER" in
  zip)
    (cd "$DIST_DIR" && zip -q -r -X "$ZIP_NAME" "$SKILL_LOWER")
    ;;
  python)
    [ -n "$PY" ] || die 'RELEASE_SKILL_PACKER=python 但未找到 python'
    "$PY" - "$LOWER_DIR" "$DIST_DIR" "$ZIP_NAME" <<'PYEOF'
import os
import sys
import zipfile

lower_dir, dist_dir, zip_name = sys.argv[1:4]
root = os.path.abspath(lower_dir)
base = os.path.dirname(root)
with zipfile.ZipFile(os.path.join(dist_dir, zip_name), "w", zipfile.ZIP_DEFLATED) as zf:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            path = os.path.join(dirpath, name)
            zf.write(path, os.path.relpath(path, base))
PYEOF
    ;;
  *) die "未知打包方式: $PACKER" ;;
esac
[ -f "$ZIP_PATH" ] || die 'zip 生成失败'
log "已生成: $ZIP_PATH"

if command -v unzip >/dev/null 2>&1; then
  unzip -l "$ZIP_PATH" | sed "s/^/$PREFIX /"
elif [ -n "$PY" ]; then
  "$PY" -m zipfile -l "$ZIP_PATH" | sed "s/^/$PREFIX /"
fi

# ---------- 4. 输出与上传 ----------
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "zip-name=$ZIP_NAME"
    echo "zip-path=$ZIP_PATH"
    echo "version=$VERSION"
  } >>"$GITHUB_OUTPUT"
fi

if [ "${RELEASE_SKILL_SKIP_UPLOAD:-0}" = 1 ]; then
  log 'RELEASE_SKILL_SKIP_UPLOAD=1，跳过上传'
  log "完成: $ZIP_NAME（版本 $VERSION）"
  exit 0
fi

command -v gh >/dev/null 2>&1 || die '未找到 gh CLI，无法上传'
[ -n "$TOKEN_INPUT" ] || die '缺少 token 输入，无法上传 Release'
[ -n "${GITHUB_REPOSITORY:-}" ] || die '缺少 GITHUB_REPOSITORY 环境变量'
[ -n "$TAG" ] || die '无法确定 Release tag（请提供 tag 输入或以 tag 推送触发）'
export GH_TOKEN="$TOKEN_INPUT"
export GH_REPO="$GITHUB_REPOSITORY"

if gh release view "$TAG" >/dev/null 2>&1; then
  log "Release 已存在，上传并覆盖同名资产: $TAG"
  gh release upload "$TAG" "$ZIP_PATH" --clobber
else
  log "创建 Release: $TAG"
  create_args=(--title "${SKILL_NAME}-Skill-${VERSION}" --generate-notes)
  if [ -n "${GITHUB_SHA:-}" ]; then
    create_args+=(--target "$GITHUB_SHA")
  fi
  gh release create "$TAG" "$ZIP_PATH" "${create_args[@]}"
fi

RELEASE_URL="$(gh release view "$TAG" --json url --jq .url 2>/dev/null || true)"
if [ -n "$RELEASE_URL" ]; then
  log "Release 地址: $RELEASE_URL"
fi
log "完成: $ZIP_NAME（版本 $VERSION）"
