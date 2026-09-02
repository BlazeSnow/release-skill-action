#!/usr/bin/env bash
# 自测：构造样例 Skill，验证白名单复制、版本号来源与 zip 结构（不上传）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/release-skill.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || {
  printf '[self-test] 失败: 未找到 python\n' >&2
  exit 1
}

fail() {
  printf '[self-test] 失败: %s\n' "$*" >&2
  exit 1
}
pass() { printf '[self-test] %s\n' "$*"; }

make_base() { # $1=BASE 目录
  local base="$1"
  mkdir -p "$base/references" "$base/scripts" "$base/docs"
  printf '# Test Skill\n\n测试内容\n' >"$base/SKILL.md"
  printf '参考内容\n' >"$base/references/guide.md"
  printf 'echo ok\n' >"$base/scripts/run.sh"
  printf 'CHANGELOG\n' >"$base/CHANGELOG.md"
  printf '额外文件\n' >"$base/extra.txt"
  printf '嵌套额外文件\n' >"$base/docs/note.txt"
  printf '不应打包\n' >"$base/secret.txt"
}

run_pack() { # $1=工作目录，其余为传给脚本的 VAR=value 环境变量
  local ws="$1"
  shift
  (cd "$ws" && GITHUB_WORKSPACE="$ws" "$@" RELEASE_SKILL_SKIP_UPLOAD=1 bash "$SCRIPT")
}

# ---------- 用例1: VERSION 文件决定版本号（含 CRLF），白名单 + 额外文件 ----------
CASE1="$TMP/case1"
mkdir -p "$CASE1/base"
make_base "$CASE1/base"
printf '1.2.3\r\n' >"$CASE1/base/VERSION"

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

# ---------- 用例3: 缺少 SKILL.md 时应当报错退出 ----------
CASE3="$TMP/case3"
mkdir -p "$CASE3/base"
if run_pack "$CASE3" env \
  'INPUT_SKILL-NAME=Broken' \
  'INPUT_SKILL-LOWER-NAME=broken' \
  'INPUT_BASE-DIR=base'; then
  fail '用例3: 缺少 SKILL.md 时应当报错退出'
fi
pass '用例3通过: 缺白名单必需项时报错'

# ---------- 用例4: 仅含 SKILL.md 的最小 Skill（无 references/scripts）应可打包 ----------
CASE4="$TMP/case4"
mkdir -p "$CASE4/base"
printf '# Minimal\n' >"$CASE4/base/SKILL.md"

run_pack "$CASE4" env \
  'INPUT_SKILL-NAME=Minimal' \
  'INPUT_SKILL-LOWER-NAME=minimal' \
  'INPUT_BASE-DIR=base' \
  'INPUT_TOKEN=fake-token' \
  GITHUB_REF_NAME=v0.1.0

"$PY" - "$CASE4" <<'PYEOF'
import os
import sys
import zipfile

ws = sys.argv[1]
zip_path = os.path.join(ws, "dist", "Minimal-Skill-v0.1.0.zip")
assert os.path.isfile(zip_path), f"缺少 zip: {zip_path}"
files = {n for n in zipfile.ZipFile(zip_path).namelist() if not n.endswith("/")}
assert files == {"minimal/SKILL.md"}, f"zip 内容不符合预期: {sorted(files)}"
print("[self-test] 用例4: 最小 Skill 打包校验通过")
PYEOF
pass '用例4通过: 无 references/scripts 的最小 Skill 可正常打包'

# ---------- 用例5: 假 gh 验证创建参数（release-body/prerelease/draft 映射） ----------
CASE5="$TMP/case5"
mkdir -p "$CASE5/base" "$CASE5/fakebin"
printf '# Body Skill\n' >"$CASE5/base/SKILL.md"
cat >"$CASE5/fakebin/gh" <<'FAKEGH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
if [ "${1:-}" = release ] && [ "${2:-}" = view ]; then
  case "$*" in
    *--json*) printf 'https://example.com/release\n'
      exit 0 ;;
    *) exit 1 ;;
  esac
fi
exit 0
FAKEGH
chmod +x "$CASE5/fakebin/gh"

(
  cd "$CASE5" && GITHUB_WORKSPACE="$CASE5" \
    PATH="$CASE5/fakebin:$PATH" \
    FAKE_GH_LOG="$CASE5/gh.log" \
    GITHUB_REPOSITORY=example/skill \
    env \
    'INPUT_SKILL-NAME=Body Skill' \
    'INPUT_SKILL-LOWER-NAME=body-skill' \
    'INPUT_BASE-DIR=base' \
    'INPUT_TOKEN=fake-token' \
    'INPUT_RELEASE-BODY=自定义说明内容' \
    'INPUT_PRERELEASE=true' \
    'INPUT_DRAFT=true' \
    GITHUB_REF_NAME=v0.5.0 \
    bash "$SCRIPT"
)

create_line="$(grep '^release create ' "$CASE5/gh.log")"
[ -n "$create_line" ] || fail '用例5: 未调用 gh release create'
grep -F -- '--notes 自定义说明内容' "$CASE5/gh.log" >/dev/null || fail '用例5: release-body 未映射为 --notes'
grep -F -- '--prerelease' "$CASE5/gh.log" >/dev/null || fail '用例5: prerelease 未映射为 --prerelease'
grep -F -- '--draft' "$CASE5/gh.log" >/dev/null || fail '用例5: draft 未映射为 --draft'
if grep -q -- '--generate-notes' "$CASE5/gh.log"; then
  fail '用例5: 提供 release-body 时不应使用 --generate-notes'
fi
pass '用例5通过: release-body/prerelease/draft 正确映射到 gh 参数'

pass '全部自测通过'
