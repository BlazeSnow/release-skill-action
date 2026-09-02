# 公共工具：日志、报错（由 release-skill.sh source）
PREFIX='[release-skill]'

log() { printf '%s %s\n' "$PREFIX" "$*"; }

die() {
  printf '%s 错误: %s\n' "$PREFIX" "$*" >&2
  exit 1
}

find_python() { command -v python3 || command -v python; }
