# generate-release-notes

GitHub Action：自动从 main 分支到当前分支的提交中生成 Changelog，按照提交类型（feat、fix、docs 等）进行分类，输出格式化的 Markdown 内容。

## 功能特性

- 自动对比分支提交，无需手动维护
- 按 8 种类型分类提交（新功能、问题修复、文档更新等）
- 生成清晰的 Markdown 格式输出，包含 emoji 标签
- 支持自定义基础分支（默认 main）
- 无外部 API 调用，完全本地处理

## 使用示例

```yaml
- name: 生成更新日志
  uses: Liar0320/generate-release-notes@v1.0.0
  id: release
  with:
    base-branch: main

- name: 查看生成的 Changelog
  run: echo "${{ steps.release.outputs.changelog }}"
```

## 输入参数

| 名称 | 必填 | 默认值 | 说明 |
| ---- | ---- | ------ | ---- |
| `base-branch` | 否 | `main` | 用于对比的基础分支 |
| `output-file` | 否 | 空 | 本地文件路径，留空则不生成文件（例如：`CHANGELOG.md`） |

## 输出参数

| 名称 | 说明 |
| ---- | ---- |
| `changelog` | 生成的 Changelog 内容（Markdown 格式） |
| `changelog-file` | 生成的文件路径（如果 `output-file` 为空则返回空值） |

## 工作流示例

### 基础使用

```yaml
name: Generate Release Notes

on: [push, pull_request]

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: 生成 Changelog
        uses: ./
        id: release

      - name: 显示结果
        run: |
          echo "生成的 Changelog："
          echo "${{ steps.release.outputs.changelog }}"
```

### 生成本地 CHANGELOG.md 文件

```yaml
name: Generate and Save Changelog

on: [push, pull_request]

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: 生成 Changelog 到本地文件
        uses: ./
        id: release
        with:
          output-file: CHANGELOG.md

      - name: 查看生成的文件
        run: cat CHANGELOG.md
```

### 与 wecom-notify 组合推送到企业微信

```yaml
name: Generate Changelog and Notify

on:
  push:
    branches:
      - main

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: 生成 Changelog
        uses: Liar0320/generate-release-notes@v1.0.0
        id: release
        with:
          output-file: CHANGELOG.md
          base-branch: main

      - name: 推送到企业微信
        uses: Liar0320/wecom-notify@v1.0.0
        with:
          body_path: CHANGELOG.md
          robots_key: ${{ secrets.WECOM_ROBOTS_KEY }}
```

### 与 GitHub Release 组合

```yaml
name: Create Release with Changelog

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: 生成 Changelog
        uses: Liar0320/generate-release-notes@v1.0.0
        id: release
        with:
          base-branch: main

      - name: 创建 Release
        uses: softprops/action-gh-release@v1
        with:
          body: ${{ steps.release.outputs.changelog }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 提交消息规范

为了更好的分类效果，建议使用以下提交消息前缀：

- `feat:` 新功能
- `fix:` 问题修复
- `docs:` 文档更新
- `style:` 样式优化
- `refactor:` 代码重构
- `perf:` 性能优化
- `chore:` 构建/工具变更
- `test:` 测试相关

例如：
```
feat: 添加用户认证功能
fix: 修复登录页面样式问题
docs: 更新 API 文档
```

## 运行时依赖

- `git` - GitHub Actions runner 默认包含
- `bash` - GitHub Actions runner 默认包含

## 许可证

本项目基于 MIT License 发布。
