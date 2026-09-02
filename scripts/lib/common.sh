# 公共工具：日志、报错、复合动作 input 读取（由 release-skill.sh source）
PREFIX='[release-skill]'

log() { printf '%s %s\n' "$PREFIX" "$*"; }

die() {
  printf '%s 错误: %s\n' "$PREFIX" "$*" >&2
  exit 1
}

# input 通过 INPUT_<大写名称> 环境变量传入（连字符保留，只能用 printenv 读取）
get_input() { printenv "INPUT_$1" 2>/dev/null | tr -d '\r' || true; }

find_python() { command -v python3 || command -v python; }
