# zip 打包（由 release-skill.sh source）

# $1=dist/<小写名称> 目录 $2=dist 目录 $3=zip 文件名
pack_zip() {
  local lower_dir="$1" dist_dir="$2" zip_name="$3"
  local zip_path="$dist_dir/$zip_name"
  local py packer
  py="$(find_python || true)"
  packer="${RELEASE_SKILL_PACKER:-auto}"
  if [ "$packer" = auto ]; then
    if command -v zip >/dev/null 2>&1; then
      packer=zip
    elif [ -n "$py" ]; then
      packer=python
    else
      die '未找到可用的打包工具（zip 或 python）'
    fi
  fi

  log "打包（$packer）: $zip_name"
  case "$packer" in
    zip)
      (cd "$dist_dir" && zip -q -r -X "$zip_name" "$(basename "$lower_dir")")
      ;;
    python)
      [ -n "$py" ] || die 'RELEASE_SKILL_PACKER=python 但未找到 python'
      "$py" - "$lower_dir" "$dist_dir" "$zip_name" <<'PYEOF'
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
    *) die "未知打包方式: $packer" ;;
  esac
  [ -f "$zip_path" ] || die 'zip 生成失败'
  log "已生成: $zip_path"

  if command -v unzip >/dev/null 2>&1; then
    unzip -l "$zip_path" | sed "s/^/$PREFIX /"
  elif [ -n "$py" ]; then
    "$py" -m zipfile -l "$zip_path" | sed "s/^/$PREFIX /"
  fi
}
