# 读取 VERSION 并创建、推送对应 git tag，推送后由 release.yml 自动创建 GitHub Release
# 用法：先提交 VERSION 变更，再运行 .\tag.ps1
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Fail([string]$Message) {
    Write-Host "tag.ps1 错误: $Message" -ForegroundColor Red
    exit 1
}

# 1. 读取版本号
$versionFile = Join-Path $PSScriptRoot 'VERSION'
if (-not (Test-Path -LiteralPath $versionFile)) { Fail '未找到 VERSION 文件' }
$version = (Get-Content -LiteralPath $versionFile -TotalCount 1 -Encoding UTF8).Trim()
if (-not $version) { Fail 'VERSION 文件为空' }
if ($version -notmatch '^v[0-9]') { Fail "版本号须以 v 开头并跟数字，当前为: '$version'" }

# 2. 工作区必须干净，确保 tag 指向的提交包含当前 VERSION
$dirty = @(git status --porcelain)
if ($dirty.Count -gt 0) {
    Fail ("工作区存在未提交变更，请先提交（否则 tag 将缺少 VERSION 更新）:`n" + ($dirty -join "`n"))
}

# 3. 查重：本地与远端
if (git tag --list $version) { Fail "本地已存在 tag: $version" }
git ls-remote --exit-code --tags origin "refs/tags/$version" | Out-Null
if ($LASTEXITCODE -eq 0) { Fail "远端已存在 tag: $version" }
if ($LASTEXITCODE -ne 2) { Fail "查询远端 tag 失败（git ls-remote exit=$LASTEXITCODE）" }

# 4. 交互确认：输入 y 才继续
$commit = git log -1 --format='%h %s'
Write-Host "即将创建并推送 tag: $version（指向提交 $commit）" -ForegroundColor Yellow
$answer = Read-Host '确认请输入 y'
if ("$answer" -ne 'y' -and "$answer" -ne 'Y') {
    Write-Host '已取消，未创建 tag' -ForegroundColor Yellow
    exit 1
}

# 5. 创建并推送 tag
git tag $version
if ($LASTEXITCODE -ne 0) { Fail '创建 tag 失败' }
git push origin "refs/tags/$version"
if ($LASTEXITCODE -ne 0) { Fail '推送 tag 失败' }

Write-Host "已推送 tag: $version" -ForegroundColor Green
Write-Host 'GitHub Actions release.yml 将自动校验并创建 Release'
