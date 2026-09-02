# GitHub Release 创建与资产上传（由 release-skill.sh source）

# $1=zip 路径 $2=tag $3=Release 标题 $4=说明正文 $5=prerelease $6=draft $7=token
upload_release() {
  local zip_path="$1" tag="$2" title="$3" body="$4" prerelease="$5" draft="$6" token="$7"
  command -v gh >/dev/null 2>&1 || die '未找到 gh CLI，无法上传'
  [ -n "$token" ] || die '缺少 token 输入，无法上传 Release'
  [ -n "${GITHUB_REPOSITORY:-}" ] || die '缺少 GITHUB_REPOSITORY 环境变量'
  export GH_TOKEN="$token"
  export GH_REPO="$GITHUB_REPOSITORY"

  if gh release view "$tag" >/dev/null 2>&1; then
    log "Release 已存在，上传并覆盖同名资产: $tag"
    gh release upload "$tag" "$zip_path" --clobber
    return
  fi

  log "创建 Release: $tag"
  local create_args=(--title "$title")
  if [ -n "$body" ]; then
    create_args+=(--notes "$body")
  else
    create_args+=(--generate-notes)
  fi
  if [ -n "${GITHUB_SHA:-}" ]; then
    create_args+=(--target "$GITHUB_SHA")
  fi
  if [ "$prerelease" = true ]; then
    create_args+=(--prerelease)
  fi
  if [ "$draft" = true ]; then
    create_args+=(--draft)
  fi
  gh release create "$tag" "$zip_path" "${create_args[@]}"
}

print_release_url() { # $1=tag
  local url
  url="$(gh release view "$1" --json url --jq .url 2>/dev/null || true)"
  if [ -n "$url" ]; then
    log "Release 地址: $url"
  fi
}
