# release-skill-action

将 Skill 按白名单打包为 zip 并上传至 GitHub Release 的 GitHub Action（composite）。

## 使用

在被打包的 Skill 所在仓库中创建 workflow：

```yaml
name: Release Skill

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: BlazeSnowSkill/release-skill-action@v1
        with:
          skill-name: MySkill
          skill-lower-name: myskill
          base-dir: .
          extra-files: |
            extra.txt
            assets/icons
```

## 输入

| 输入 | 必填 | 说明 |
| --- | --- | --- |
| `skill-name` | 是 | Skill 名称，用于 zip 文件名 |
| `skill-lower-name` | 是 | Skill 小写名称（实际部署名称），同时是 zip 内的根目录名 |
| `base-dir` | 是 | BASE 目录，白名单文件所在位置（相对仓库根目录） |
| `extra-files` | 否 | 额外复制的文件或文件夹，每行一个，相对 BASE 目录，支持 `#` 注释 |
| `tag` | 否 | 目标 Release 的 tag，默认取当前 ref 名（建议以 tag 推送触发） |
| `token` | 否 | GitHub Token，默认 `github.token` |

## 输出

| 输出 | 说明 |
| --- | --- |
| `zip-name` | 生成的 zip 文件名 |
| `zip-path` | 生成的 zip 文件绝对路径 |
| `version` | 使用的版本号 |

## 打包规则

1. 将 BASE 目录中的白名单文件复制到 `dist/<skill-lower-name>`：
   - 必需：`SKILL.md`（缺失时直接报错）
   - 可选：`references/`、`scripts/`、`CHANGELOG.md`、`LICENSE`、`README.md`、`VERSION`
2. 以 `<skill-lower-name>` 为根目录打包为 zip。
3. zip 文件名为 `<skill-name>-Skill-<版本号>.zip`。
4. 上传至 GitHub Release：Release 已存在则上传并覆盖同名资产，不存在则创建并自动生成说明。

## 版本号

优先级从高到低：

1. BASE 目录中 `VERSION` 文件的第一行
2. `tag` 输入
3. 当前 ref 名（`github.ref_name`，如 tag 推送时的 `v1.2.3`）

## 开发

实现说明、本地自测与编码约定见 [DEVELOPMENT.md](DEVELOPMENT.md)。
