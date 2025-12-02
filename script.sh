#!/bin/bash

set -euo pipefail

BASE_BRANCH="${1:-main}"
OUTPUT_FILE="${2:-}"

echo "📝 生成从 $BASE_BRANCH 分支到当前分支的更新日志..."

# 获取 base 分支的最新提交
git fetch origin "$BASE_BRANCH":"$BASE_BRANCH" 2>/dev/null || git fetch origin "$BASE_BRANCH" || {
  echo "⚠️  无法获取 $BASE_BRANCH 分支" >&2
  echo "changelog=无法获取基础分支" >> "$GITHUB_OUTPUT"
  exit 0
}

# 获取提交列表（从 base 分支分叉点到 HEAD）
COMMITS=$(git log --oneline --no-merges "$BASE_BRANCH"..HEAD 2>/dev/null || echo "")

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
  COMMIT_COUNT=$(echo "$COMMITS" | wc -l)
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

# 构建完整的 Release Notes 并输出
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

# 如果指定了输出文件，将完整的 Release Notes 写入文件
if [ -n "$OUTPUT_FILE" ]; then
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
  echo "changelog-file=$OUTPUT_FILE" >> "$GITHUB_OUTPUT"
  echo "✅ Release Notes 已写入文件: $OUTPUT_FILE"
else
  echo "changelog-file=" >> "$GITHUB_OUTPUT"
  echo "✅ Changelog 生成完成"
fi
