# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitHub Action that automatically generates Changelog from git commits between a base branch (default: main) and the current branch. The action analyzes commit messages, categorizes them by type (feat, fix, docs, etc.), and outputs a formatted Markdown changelog with emoji labels.

## Key Files

- `action.yaml`: Main action definition with inputs, outputs, and shell script logic
- `README.md`: User documentation with usage examples and commit message conventions
- `.github/workflows/test_with_local_actions.yaml`: Tests the local action (uses `./`)
- `.github/workflows/test_with_marketplace_actions.yaml`: Tests the published marketplace version

## Action Configuration

### Inputs
- `base-branch` (optional, default: "main"): Base branch to compare against

### Outputs
- `changelog`: Generated changelog content in Markdown format

## Core Logic

The action performs the following steps:

1. **Fetch base branch** - Ensures the base branch reference exists locally
2. **Get commits** - Uses `git log --oneline --no-merges [base-branch]..HEAD` to get new commits
3. **Categorize commits** - Uses `grep` to filter commits by type prefix:
   - `feat:` → ✨ 新功能 (New Features)
   - `fix:` → 🐛 问题修复 (Bug Fixes)
   - `style:` → 💄 样式优化 (Style Changes)
   - `refactor:` → ♻️ 代码重构 (Code Refactoring)
   - `perf:` → ⚡ 性能优化 (Performance)
   - `docs:` → 📝 文档更新 (Documentation)
   - `chore:` → 🔧 构建/工具 (Build/Tools)
   - `test:` → ✅ 测试 (Tests)
   - Others → 📦 其他更新 (Other)

4. **Build output** - Constructs multi-line Markdown with only non-empty categories
5. **Output result** - Writes to `$GITHUB_OUTPUT` using heredoc syntax for proper multi-line handling

## How It Works

The script uses bash string matching with `grep -i` (case-insensitive) to detect commit types. Empty categories are skipped from output. Multi-line output is handled via the heredoc EOF format to maintain compatibility with GitHub Actions output variables.

## Common Usage Patterns

### Basic Usage
```yaml
- name: Generate Changelog
  uses: Liar0320/generate-release-notes@v1.0.0
  id: release

- name: Display Changelog
  run: echo "${{ steps.release.outputs.changelog }}"
```

### With GitHub Release
```yaml
- name: Generate Changelog
  uses: Liar0320/generate-release-notes@v1.0.0
  id: release
  with:
    base-branch: main

- name: Create Release
  uses: softprops/action-gh-release@v1
  with:
    body: ${{ steps.release.outputs.changelog }}
```

### Custom Base Branch
```yaml
- name: Generate Changelog from develop
  uses: Liar0320/generate-release-notes@v1.0.0
  id: release
  with:
    base-branch: develop
```

## Development Notes

- Uses only standard Unix tools: `git`, `bash`, `grep`
- No external dependencies or API calls
- Works with shallow clones when using `fetch-depth: 0` in checkout
- Case-insensitive commit message matching for flexibility
- Gracefully handles scenarios with no new commits or missing branches