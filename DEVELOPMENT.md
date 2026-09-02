# DEVELOPMENT

面向本仓库开发者的说明：项目结构、实现细节、本地自测与编码约定。

## 项目结构

| 文件 | 说明 |
| --- | --- |
| `action.yml` | composite action 入口，定义输入输出 |
| `scripts/release-skill.sh` | 核心脚本：白名单复制、版本号解析、打包、上传 |
| `scripts/verify-tag-version.sh` | release.yml 使用：校验触发 tag 与 VERSION 文件一致 |
| `scripts/update-major-tag.sh` | release.yml 使用：正式版强制更新主版本标签 |
| `tests/self-test.sh` | 自测脚本（不上传，仅验证打包） |
| `VERSION` | 本仓库自身的版本号，与发布的 tag 保持一致 |
| `tag.ps1` | 本地发布脚本：校验工作区后推送 VERSION 对应的 tag |
| `.github/workflows/ci.yml` | push/PR 时在 ubuntu 上运行自测 |
| `.github/workflows/release.yml` | tag 推送时校验一致性、自测、创建 Release 并更新主版本标签 |

## 发布流程

1. 修改 `VERSION`（如 `v1.0-beta.1`）并提交。
2. 运行 `./tag.ps1`：校验工作区干净、版本号格式、本地与远端无同名 tag 后，推送该 tag。
3. `release.yml` 自动执行：
   - 校验 tag 与 `VERSION` 一致（防止忘记更新 VERSION）；
   - 运行自测；
   - 用 `ncipollo/release-action@v1` 创建 GitHub Release（自动生成说明；tag 含 `-` 自动标记为 prerelease，`allowUpdates` 允许重跑覆盖）；
   - 仅正式版强制更新主版本标签（如 `v1.0.0` → `v1`）。预发布版本（如 `v1.0-beta.1`）不移动 `@v1`，使用方通过 `uses: BlazeSnowSkill/release-skill-action@v1` 始终引用正式版。

`tag.ps1` 为 UTF-8（带 BOM）+ CRLF 编码，兼容 Windows PowerShell 5.1 的中文输出。

## 实现说明

- **输入读取**：复合动作的 input 以 `INPUT_<大写名称>` 环境变量传入，名称中的连字符保留，bash 无法以 `$` 直接引用，脚本统一通过 `printenv` 读取并剔除 `\r`。
- **白名单复制**：必需项（`SKILL.md`）缺失时直接报错退出；可选项（`references/`、`scripts/`、`CHANGELOG.md`、`LICENSE`、`README.md`、`VERSION`）缺失时记录日志并跳过；`extra-files` 每行一个，支持 `#` 注释，禁止上级路径逃逸。
- **版本号**：`VERSION` 文件第一行 > `tag` 输入 > `GITHUB_REF_NAME`；读取时剔除首尾空白与 `\r`。
- **打包**：优先使用 `zip`，找不到时回退 Python `zipfile`（可用环境变量 `RELEASE_SKILL_PACKER=zip|python` 强制指定）。Python 路径对非 ASCII 文件名会正确写入 UTF-8 标志位。
- **上传**：通过 `gh` CLI；Release 已存在则 `gh release upload --clobber` 覆盖同名资产，不存在则 `gh release create --generate-notes` 创建。
- **测试钩子**：`RELEASE_SKILL_SKIP_UPLOAD=1` 跳过上传，供本地与 CI 自测使用。

## 本地自测

```bash
bash tests/self-test.sh
```

用例覆盖：

1. `VERSION` 文件决定版本号（含 CRLF 内容），白名单与额外文件正确复制、白名单外文件排除、`GITHUB_OUTPUT` 输出、zip 内 UTF-8 内容逐字节一致。
2. 无 `VERSION` 文件时版本号回退到 ref 名，并强制 `RELEASE_SKILL_PACKER=python` 验证回退打包路径。
3. 缺少必需项（`SKILL.md`）时脚本报错退出。
4. 仅含 `SKILL.md` 的最小 Skill（无 `references/`、`scripts/`）可正常打包。

CI 在 ubuntu runner 上运行同一脚本，天然覆盖 `zip` 打包路径；本地（Windows Git Bash）通常无 `zip`，覆盖 Python 路径。

## 编码约定

- workflow 不放内联脚本，逻辑一律拆到 `scripts/` 下的 sh 文件，workflow 里只写 `bash scripts/xxx.sh`。
- shell 脚本用 [shfmt](https://github.com/mvdan/sh) 格式化：`shfmt -w -i 2 -bn -ci scripts/*.sh tests/*.sh`。
- 仓库内脚本与配置均为 UTF-8（无 BOM）、LF 换行，`.gitattributes` 已约束；Windows 下开发请勿改为 GBK 或 CRLF。
- 读取 `VERSION` 与 `extra-files` 时会剔除 `\r`，兼容 CRLF 内容。
- zip 内文件名以 UTF-8 编码写入。
