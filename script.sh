#!/bin/bash

set -euo pipefail

COMPARE_MODE="${1:-branch}"
BASE_BRANCH="${2:-main}"
OUTPUT_FILE="${3:-}"

# 用于存储标签比较信息
CURRENT_TAG=""
PREVIOUS_TAG=""
COMPARE_BASE=""
COMPARE_DISPLAY=""

# 获取提交列表的函数
get_commits() {
  local base="$1"
  git log --oneline --no-merges "${base}..HEAD" 2>/dev/null || echo ""
}

# 按语义版本排序标签（支持 v 前缀和 prerelease）
sort_tags_semver() {
  # 使用 sort -V 进行版本排序，处理 v 前缀
  sort -t. -k1,1 -k2,2 -k3,3 -V
}

# 查找上一个版本标签
find_previous_tag() {
  local current_tag="$1"
  local all_tags

  # 获取所有标签并按版本排序
  all_tags=$(git tag -l | sort_tags_semver)

  if [ -z "$all_tags" ]; then
    echo ""
    return
  fi

  # 找到当前标签在排序列表中的位置，返回前一个
  local prev_tag=""
  while IFS= read -r tag; do
    if [ "$tag" = "$current_tag" ]; then
      echo "$prev_tag"
      return
    fi
    prev_tag="$tag"
  done <<< "$all_tags"

  echo ""
}

# 标签比较模式
if [ "$COMPARE_MODE" = "tag" ]; then
  echo "📝 使用标签比较模式，自动检测版本标签..."

  # 获取所有标签
  git fetch --tags 2>/dev/null || true

  # 获取当前 commit 的标签
  CURRENT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")

  if [ -z "$CURRENT_TAG" ]; then
    # 如果当前 commit 没有标签，尝试获取最近的标签
    CURRENT_TAG=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")
  fi

  if [ -z "$CURRENT_TAG" ]; then
    echo "⚠️  无法找到任何版本标签，回退到分支比较模式"
    COMPARE_MODE="branch"
  else
    # 查找上一个版本标签
    PREVIOUS_TAG=$(find_previous_tag "$CURRENT_TAG")

    if [ -z "$PREVIOUS_TAG" ]; then
      echo "⚠️  无法找到上一个版本标签，将显示从第一个提交到 $CURRENT_TAG 的所有变更"
      # 获取仓库的第一个提交
      COMPARE_BASE=$(git rev-list --max-parents=0 HEAD 2>/dev/null | head -1)
      COMPARE_DISPLAY="初始版本"
    else
      COMPARE_BASE="$PREVIOUS_TAG"
      COMPARE_DISPLAY="$PREVIOUS_TAG"
      echo "📌 比较: $PREVIOUS_TAG → $CURRENT_TAG"
    fi
  fi
fi

# 分支比较模式（或标签模式回退）
if [ "$COMPARE_MODE" = "branch" ]; then
  echo "📝 生成从 $BASE_BRANCH 分支到当前分支的更新日志..."

  # 获取 base 分支的最新提交
  git fetch origin "$BASE_BRANCH":"$BASE_BRANCH" 2>/dev/null || git fetch origin "$BASE_BRANCH" || {
    echo "⚠️  无法获取 $BASE_BRANCH 分支" >&2
    echo "changelog=无法获取基础分支" >> "$GITHUB_OUTPUT"
    exit 0
  }

  COMPARE_BASE="$BASE_BRANCH"
  COMPARE_DISPLAY="$BASE_BRANCH 分支"
fi

# 获取提交列表
COMMITS=$(get_commits "$COMPARE_BASE")

# 检查是否有新提交
HAS_COMMITS=true
if [ -z "$COMMITS" ]; then
  HAS_COMMITS=false
  echo "⚠️  未检测到新提交"
fi

# 构建 changelog
CHANGELOG=""

if [ "$HAS_COMMITS" = true ]; then
  # 分类提交
  FEAT=$(echo "$COMMITS" | grep -i "^[^ ]* feat" || true)
  FIX=$(echo "$COMMITS" | grep -i "^[^ ]* fix" || true)
  STYLE=$(echo "$COMMITS" | grep -i "^[^ ]* style" || true)
  REFACTOR=$(echo "$COMMITS" | grep -i "^[^ ]* refactor" || true)
  PERF=$(echo "$COMMITS" | grep -i "^[^ ]* perf" || true)
  DOCS=$(echo "$COMMITS" | grep -i "^[^ ]* docs" || true)
  CHORE=$(echo "$COMMITS" | grep -i "^[^ ]* chore" || true)
  TEST=$(echo "$COMMITS" | grep -i "^[^ ]* test" || true)
  OTHER=$(echo "$COMMITS" | grep -iv "^[^ ]* \(feat\|fix\|style\|refactor\|perf\|docs\|chore\|test\)" || true)

  if [ -n "$FEAT" ]; then
    CHANGELOG="${CHANGELOG}### ✨ 新功能
$FEAT

"
  fi

  if [ -n "$FIX" ]; then
    CHANGELOG="${CHANGELOG}### 🐛 问题修复
$FIX

"
  fi

  if [ -n "$STYLE" ]; then
    CHANGELOG="${CHANGELOG}### 💄 样式优化
$STYLE

"
  fi

  if [ -n "$REFACTOR" ]; then
    CHANGELOG="${CHANGELOG}### ♻️ 代码重构
$REFACTOR

"
  fi

  if [ -n "$PERF" ]; then
    CHANGELOG="${CHANGELOG}### ⚡ 性能优化
$PERF

"
  fi

  if [ -n "$DOCS" ]; then
    CHANGELOG="${CHANGELOG}### 📝 文档更新
$DOCS

"
  fi

  if [ -n "$CHORE" ]; then
    CHANGELOG="${CHANGELOG}### 🔧 构建/工具
$CHORE

"
  fi

  if [ -n "$TEST" ]; then
    CHANGELOG="${CHANGELOG}### ✅ 测试
$TEST

"
  fi

  if [ -n "$OTHER" ]; then
    CHANGELOG="${CHANGELOG}### 📦 其他更新
$OTHER

"
  fi
else
  CHANGELOG="暂无新提交"
fi

# 获取必要的变量
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [ "$HAS_COMMITS" = true ]; then
  COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
  COMMIT_HASH="${GITHUB_SHA:0:7}"
  COMMIT_MESSAGE=$(git log -1 --pretty=%s 2>/dev/null || echo "Auto-generated release notes")
else
  COMMIT_COUNT=0
  COMMIT_HASH="${GITHUB_SHA:0:7}"
  COMMIT_MESSAGE="无新提交"
fi

# 输出纯 changelog
{
  echo "changelog<<EOF"
  echo "$CHANGELOG"
  echo "EOF"
} >> "$GITHUB_OUTPUT"

# 构建完整的 Release Notes
if [ "$COMPARE_MODE" = "tag" ] && [ -n "$CURRENT_TAG" ]; then
  # 标签模式的 Release Notes
  {
    echo "release-notes<<EOF"
    echo "🧪 **构建信息**"
    echo "🏷️ 当前版本: $CURRENT_TAG"
    echo "🏷️ 上一版本: $COMPARE_DISPLAY"
    echo "🌿 当前分支: $CURRENT_BRANCH"
    echo "🔢 提交数量: $COMMIT_COUNT"
    echo "🔖 Commit: $COMMIT_HASH - $COMMIT_MESSAGE"
    echo ""
    echo "## 📋 更新内容 ($COMPARE_DISPLAY → $CURRENT_TAG)"
    echo ""
    echo "$CHANGELOG"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"

  # 输出标签信息
  echo "current-tag=$CURRENT_TAG" >> "$GITHUB_OUTPUT"
  echo "previous-tag=$PREVIOUS_TAG" >> "$GITHUB_OUTPUT"
else
  # 分支模式的 Release Notes
  {
    echo "release-notes<<EOF"
    echo "🧪 **构建信息**"
    echo "📌 基于分支: $BASE_BRANCH"
    echo "🌿 当前分支: $CURRENT_BRANCH"
    echo "🔢 提交数量: $COMMIT_COUNT"
    echo "🔖 Commit: $COMMIT_HASH - $COMMIT_MESSAGE"
    echo ""
    echo "## 📋 更新内容 (相对于 $BASE_BRANCH 分支)"
    echo ""
    echo "$CHANGELOG"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"

  echo "current-tag=" >> "$GITHUB_OUTPUT"
  echo "previous-tag=" >> "$GITHUB_OUTPUT"
fi

# 如果指定了输出文件，将完整的 Release Notes 写入文件
if [ -n "$OUTPUT_FILE" ]; then
  if [ "$COMPARE_MODE" = "tag" ] && [ -n "$CURRENT_TAG" ]; then
    {
      echo "🧪 **构建信息**"
      echo "🏷️ 当前版本: $CURRENT_TAG"
      echo "🏷️ 上一版本: $COMPARE_DISPLAY"
      echo "🌿 当前分支: $CURRENT_BRANCH"
      echo "🔢 提交数量: $COMMIT_COUNT"
      echo "🔖 Commit: $COMMIT_HASH - $COMMIT_MESSAGE"
      echo ""
      echo "## 📋 更新内容 ($COMPARE_DISPLAY → $CURRENT_TAG)"
      echo ""
      echo "$CHANGELOG"
    } > "$OUTPUT_FILE"
  else
    {
      echo "🧪 **构建信息**"
      echo "📌 基于分支: $BASE_BRANCH"
      echo "🌿 当前分支: $CURRENT_BRANCH"
      echo "🔢 提交数量: $COMMIT_COUNT"
      echo "🔖 Commit: $COMMIT_HASH - $COMMIT_MESSAGE"
      echo ""
      echo "## 📋 更新内容 (相对于 $BASE_BRANCH 分支)"
      echo ""
      echo "$CHANGELOG"
    } > "$OUTPUT_FILE"
  fi
  echo "changelog-file=$OUTPUT_FILE" >> "$GITHUB_OUTPUT"
  echo "✅ Release Notes 已写入文件: $OUTPUT_FILE"
else
  echo "changelog-file=" >> "$GITHUB_OUTPUT"
  echo "✅ Changelog 生成完成"
fi
