# 白名单与额外文件复制（由 release-skill.sh source）

copy_item() { # $1=BASE 目录 $2=目标目录 $3=相对路径 $4=required|optional
  local base="$1" lower="$2" rel="$3" required="$4"
  local src="$base/$rel" dest="$lower/$rel"
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

# $1=BASE 目录 $2=dist/<小写名称> 目录 $3=extra-files 输入原文
stage_whitelist() {
  local base="$1" lower="$2" extra_files="$3"
  rm -rf "$lower"
  mkdir -p "$lower"

  log '复制白名单文件:'
  copy_item "$base" "$lower" 'SKILL.md' required
  copy_item "$base" "$lower" 'references' optional
  copy_item "$base" "$lower" 'scripts' optional
  copy_item "$base" "$lower" 'CHANGELOG.md' optional
  copy_item "$base" "$lower" 'LICENSE' optional
  copy_item "$base" "$lower" 'README.md' optional
  copy_item "$base" "$lower" 'VERSION' optional

  # 额外文件或文件夹：每行一个，相对 BASE 目录，支持 # 注释
  local line entry
  while IFS= read -r line; do
    entry="${line%%#*}"
    entry="${entry#"${entry%%[![:space:]]*}"}"
    entry="${entry%"${entry##*[![:space:]]}"}"
    [ -n "$entry" ] || continue
    case "$entry" in
      .. | ../* | */.. | */../*) die "extra-files 不允许包含上级路径: $entry" ;;
    esac
    copy_item "$base" "$lower" "$entry" required
  done <<<"$extra_files"
}
