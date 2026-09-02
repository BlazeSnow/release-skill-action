# CHANGELOG

## V1.0-beta.3

1. 修复真实 runner 上带连字符输入（skill-name 等）读取失败的问题：runner 不为非法变量名注入 `INPUT_*` 环境变量，改为在 action.yml 中用 `${{ inputs.* }}` 显式映射后传入脚本

## V1.0-beta.2

1. 支持 release-body 输入
2. 支持 prerelease 与 draft 布尔参数

## V1.0-beta.1

1. 发布首个版本
