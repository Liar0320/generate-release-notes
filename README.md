# generate-release-notes

GitHub Action：自动从 main 分支到当前分支的提交中生成 Changelog，按照提交类型（feat、fix、docs 等）进行分类，并生成包含完整元数据的 Release Notes。

## 功能特性

- 自动对比分支提交，无需手动维护
- 按 8 种类型分类提交（新功能、问题修复、文档更新等）
- 生成清晰的 Markdown 格式输出，包含 emoji 标签
- 内置完整的 Release Notes 格式，包含构建信息、分支信息、提交数等元数据
- 支持自定义基础分支（默认 main）
- 无外部 API 调用，完全本地处理

## 使用示例

```yaml
- name: 生成 Release Notes
  uses: Liar0320/generate-release-notes@v1.0.0
  id: release
  with:
    base-branch: main

- name: 查看纯 Changelog
  run: echo "${{ steps.release.outputs.changelog }}"

- name: 查看完整 Release Notes
  run: echo "${{ steps.release.outputs.release-notes }}"
```

## 输入参数

| 名称 | 必填 | 默认值 | 说明 |
| ---- | ---- | ------ | ---- |
| `base-branch` | 否 | `main` | 用于对比的基础分支 |
| `output-file` | 否 | 空 | 本地文件路径，保存完整的 Release Notes（例如：`RELEASE_NOTES.md`） |

## 输出参数

| 名称 | 说明 |
| ---- | ---- |
| `changelog` | 纯 Changelog 内容（仅包含分类后的提交信息） |
| `release-notes` | 完整的 Release Notes（包含构建信息、分支、提交数、Changelog 等） |
| `changelog-file` | Release Notes 文件路径（如果 `output-file` 指定了值） |

## 工作流示例

### 基础使用 - 仅获取输出

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

      - name: 生成 Release Notes
        uses: ./
        id: release

      - name: 显示纯 Changelog
        run: |
          echo "=== 纯 Changelog ==="
          echo "${{ steps.release.outputs.changelog }}"

      - name: 显示完整 Release Notes
        run: |
          echo "=== 完整 Release Notes ==="
          echo "${{ steps.release.outputs.release-notes }}"
```

### 生成文件 - Release Notes 到本地文件

```yaml
name: Generate and Save Release Notes

on: [push, pull_request]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: 生成 Release Notes 文件
        uses: Liar0320/generate-release-notes@v1.0.0
        id: release
        with:
          output-file: RELEASE_NOTES.md
          base-branch: main

      - name: 查看生成的文件
        run: cat RELEASE_NOTES.md
```

### 与 wecom-notify 组合推送到企业微信

```yaml
name: Generate Release Notes and Notify

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

      - name: 生成 Release Notes
        uses: Liar0320/generate-release-notes@v1.0.0
        id: release
        with:
          output-file: RELEASE_NOTES.md
          base-branch: main

      - name: 推送到企业微信
        uses: Liar0320/wecom-notify@v1.0.0
        with:
          body_path: RELEASE_NOTES.md
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
