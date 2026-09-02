#!/usr/bin/env bash
# 将 Skill 按白名单打包为 zip 并上传至 GitHub Release（由 composite action 调用）
# 各阶段逻辑拆分在 scripts/lib/ 下，本文件只负责解析输入与串联流程
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/whitelist.sh"
source "$SCRIPT_DIR/lib/version.sh"
source "$SCRIPT_DIR/lib/pack.sh"
source "$SCRIPT_DIR/lib/upload.sh"

# 输入由 action.yml 的 env: 显式映射传入（runner 不为带连字符的 input 注入 INPUT_* 变量）
SKILL_NAME="${SKILL_NAME:-}"
SKILL_LOWER="${SKILL_LOWER_NAME:-}"
BASE_DIR_INPUT="${BASE_DIR:-}"
EXTRA_FILES_INPUT="${EXTRA_FILES:-}"
TAG_INPUT="${TAG:-}"
TOKEN_INPUT="${TOKEN:-}"
RELEASE_BODY="${RELEASE_BODY:-}"
PRERELEASE_INPUT="${PRERELEASE:-}"
DRAFT_INPUT="${DRAFT:-}"

REF_NAME="${GITHUB_REF_NAME:-}"
REPO_ROOT="${GITHUB_WORKSPACE:-$PWD}"

[ -n "$SKILL_NAME" ] || die '缺少输入: skill-name'
[ -n "$SKILL_LOWER" ] || die '缺少输入: skill-lower-name'
[ -n "$BASE_DIR_INPUT" ] || die '缺少输入: base-dir'

case "$SKILL_NAME" in
  -* | */*) die "skill-name 不允许以 - 开头或包含 /: $SKILL_NAME" ;;
esac
case "$SKILL_LOWER" in
  '' | . | .. | */* | *[[:space:]]*) die "skill-lower-name 须为不含空格与路径分隔符的名称: $SKILL_LOWER" ;;
esac
[ "$SKILL_LOWER" = "${SKILL_LOWER,,}" ] || die "skill-lower-name 必须全小写: $SKILL_LOWER"

case "$BASE_DIR_INPUT" in
  /* | [A-Za-z]:[\\/]*) BASE_DIR="$BASE_DIR_INPUT" ;;
  *) BASE_DIR="$REPO_ROOT/$BASE_DIR_INPUT" ;;
esac
BASE_DIR="${BASE_DIR%/}"
[ -d "$BASE_DIR" ] || die "BASE 目录不存在: $BASE_DIR"

log "Skill: $SKILL_NAME（部署名: $SKILL_LOWER）"
log "BASE 目录: $BASE_DIR"

# ---------- 1. 复制白名单到 dist/<小写名称> ----------
DIST_DIR="$REPO_ROOT/dist"
LOWER_DIR="$DIST_DIR/$SKILL_LOWER"
stage_whitelist "$BASE_DIR" "$LOWER_DIR" "$EXTRA_FILES_INPUT"

# ---------- 2. 确定版本号：VERSION 文件 > tag 输入 > 当前 ref 名 ----------
TAG="$TAG_INPUT"
[ -n "$TAG" ] || TAG="$REF_NAME"
resolve_version "$BASE_DIR" "$TAG"

# ---------- 3. 以 <小写名称> 为根目录打包 zip ----------
ZIP_NAME="${SKILL_NAME}-Skill-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
pack_zip "$LOWER_DIR" "$DIST_DIR" "$ZIP_NAME"

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

[ -n "$TAG" ] || die '无法确定 Release tag（请提供 tag 输入或以 tag 推送触发）'
upload_release "$ZIP_PATH" "$TAG" "${SKILL_NAME}-Skill-${VERSION}" "$RELEASE_BODY" "$PRERELEASE_INPUT" "$DRAFT_INPUT" "$TOKEN_INPUT"
print_release_url "$TAG"
log "完成: $ZIP_NAME（版本 $VERSION）"
