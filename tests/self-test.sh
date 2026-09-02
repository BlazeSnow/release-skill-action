#!/usr/bin/env bash
# 自测：构造样例 Skill，验证白名单复制、版本号来源与 zip 结构（不上传）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/release-skill.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { printf '[self-test] 失败: 未找到 python\n' >&2; exit 1; }

fail() { printf '[self-test] 失败: %s\n' "$*" >&2; exit 1; }
pass() { printf '[self-test] %s\n' "$*"; }

make_base() { # $1=BASE 目录
  local base="$1"
  mkdir -p "$base/references" "$base/scripts" "$base/docs"
  printf '# Test Skill\n\n测试内容\n' > "$base/SKILL.md"
  printf '参考内容\n' > "$base/references/guide.md"
  printf 'echo ok\n' > "$base/scripts/run.sh"
  printf 'CHANGELOG\n' > "$base/CHANGELOG.md"
  printf '额外文件\n' > "$base/extra.txt"
  printf '嵌套额外文件\n' > "$base/docs/note.txt"
  printf '不应打包\n' > "$base/secret.txt"
}

run_pack() { # $1=工作目录，其余为传给脚本的 VAR=value 环境变量
  local ws="$1"; shift
  (cd "$ws" && GITHUB_WORKSPACE="$ws" "$@" RELEASE_SKILL_SKIP_UPLOAD=1 bash "$SCRIPT")
}

# ---------- 用例1: VERSION 文件决定版本号（含 CRLF），白名单 + 额外文件 ----------
CASE1="$TMP/case1"
mkdir -p "$CASE1/base"
make_base "$CASE1/base"
printf '1.2.3\r\n' > "$CASE1/base/VERSION"

run_pack "$CASE1" env \
  'INPUT_SKILL-NAME=Test Skill' \
  'INPUT_SKILL-LOWER-NAME=test-skill' \
  'INPUT_BASE-DIR=base' \
  "INPUT_EXTRA-FILES=extra.txt
docs/note.txt" \
  'INPUT_TOKEN=fake-token' \
  GITHUB_REF_NAME=should-not-win \
  "GITHUB_OUTPUT=$CASE1/github_output"

"$PY" - "$CASE1" <<'PYEOF'
import os
import sys
import zipfile

ws = sys.argv[1]
zip_path = os.path.join(ws, "dist", "Test Skill-Skill-1.2.3.zip")
assert os.path.isfile(zip_path), f"缺少 zip: {zip_path}"
zf = zipfile.ZipFile(zip_path)
files = {n for n in zf.namelist() if not n.endswith("/")}
expected = {
    "test-skill/SKILL.md",
    "test-skill/references/guide.md",
    "test-skill/scripts/run.sh",
    "test-skill/CHANGELOG.md",
    "test-skill/VERSION",
    "test-skill/extra.txt",
    "test-skill/docs/note.txt",
}
missing = expected - files
assert not missing, f"zip 缺少文件: {sorted(missing)}"
assert all(n.startswith("test-skill/") for n in files), f"zip 根目录不是 test-skill/: {sorted(files)}"
assert "test-skill/secret.txt" not in files, "白名单外的文件被打包"
assert zf.read("test-skill/references/guide.md").decode("utf-8") == "参考内容\n", "UTF-8 内容不一致"
print("[self-test] 用例1: zip 内容与编码校验通过")
PYEOF

grep -qx 'zip-name=Test Skill-Skill-1.2.3.zip' "$CASE1/github_output" || fail 'GITHUB_OUTPUT 缺少 zip-name'
grep -qx 'version=1.2.3' "$CASE1/github_output" || fail 'GITHUB_OUTPUT 缺少 version'
grep -q '^zip-path=' "$CASE1/github_output" || fail 'GITHUB_OUTPUT 缺少 zip-path'
pass '用例1通过: VERSION 文件决定版本号，白名单/额外文件/输出变量均正确'

# ---------- 用例2: 无 VERSION 文件时版本号回退到 ref 名，且强制 python 打包路径 ----------
CASE2="$TMP/case2"
mkdir -p "$CASE2/base"
make_base "$CASE2/base"

run_pack "$CASE2" env \
  'INPUT_SKILL-NAME=Test Skill' \
  'INPUT_SKILL-LOWER-NAME=test-skill' \
  'INPUT_BASE-DIR=base' \
  'INPUT_TOKEN=fake-token' \
  GITHUB_REF_NAME=v9.8.7 \
  RELEASE_SKILL_PACKER=python

"$PY" - "$CASE2" <<'PYEOF'
import os
import sys
import zipfile

ws = sys.argv[1]
zip_path = os.path.join(ws, "dist", "Test Skill-Skill-v9.8.7.zip")
assert os.path.isfile(zip_path), f"缺少 zip: {zip_path}"
files = {n for n in zipfile.ZipFile(zip_path).namelist() if not n.endswith("/")}
assert "test-skill/VERSION" not in files, "无 VERSION 文件时不应打包 VERSION"
print("[self-test] 用例2: 版本号回退与 python 打包校验通过")
PYEOF
pass '用例2通过: 版本号回退到 ref 名'

# ---------- 用例3: 缺少白名单必需项时应当报错退出 ----------
CASE3="$TMP/case3"
mkdir -p "$CASE3/base"
if run_pack "$CASE3" env \
  'INPUT_SKILL-NAME=Broken' \
  'INPUT_SKILL-LOWER-NAME=broken' \
  'INPUT_BASE-DIR=base'; then
  fail '用例3: 缺少 SKILL.md 时应当报错退出'
fi
pass '用例3通过: 缺少白名单必需项时报错'

pass '全部自测通过'
