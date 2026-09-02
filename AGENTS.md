# release-skill-action AI开发指南

1. 禁止修改本文件
2. 开发中需要注意 GBK 和 UTF-8

## 项目目的

将 Skill 打包为 zip 并上传至 GitHub Release

## 项目参数

1. skill 名称
2. skill 小写名称（实际部署名称）
3. BASE 目录
4. 额外文件或文件夹

## 项目操作

1. 将 BASE 目录中的白名单文件复制到 `/dist/<小写名称>`
2. 以 <小写名称> 为基，打包为 zip 文件
3. zip 文件名为 <skill名称>-Skill-<版本号>.zip
4. 上传至 GitHub Release

## 白名单文件

1. references/
2. scripts/
3. SKILL.md
4. CHANGELOG.md （可选）
5. LICENSE （可选）
6. README.md （可选）
7. VERSION （可选）
