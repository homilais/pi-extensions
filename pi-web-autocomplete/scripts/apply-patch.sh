#!/bin/bash
# pi-web-autocomplete 补丁应用脚本
# 
# 用法：bash apply-patch.sh
# 
# 功能：
#   1. 备份原始 pi-web 编译文件
#   2. 应用服务端补丁（monkey-patch）
#   3. 提示客户端补丁步骤

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# pi-web 编译文件路径
PI_WEB_DIR="${PI_WEB_DIR:-$HOME/.npm-global/lib/node_modules/@agegr/pi-web}"
SERVER_CHUNK="$PI_WEB_DIR/.next/server/chunks/6429.js"

echo "=========================================="
echo "pi-web-autocomplete 补丁应用"
echo "=========================================="
echo ""

# 检查 pi-web 是否存在
if [ ! -f "$SERVER_CHUNK" ]; then
  echo "错误：找不到 pi-web 编译文件"
  echo "  路径：$SERVER_CHUNK"
  echo ""
  echo "请设置 PI_WEB_DIR 环境变量，例如："
  echo "  export PI_WEB_DIR=\$(npm root -g)/@agegr/pi-web"
  exit 1
fi

echo "pi-web 目录：$PI_WEB_DIR"
echo "服务端文件：$SERVER_CHUNK"
echo ""

# 检查是否已经应用过补丁
BACKUP_FILE="$SERVER_CHUNK.bak"
if [ -f "$BACKUP_FILE" ]; then
  echo "警告：已存在备份文件，补丁可能已应用"
  read -p "继续吗？(y/N) " -n 1
  echo
  if [[ ! "$REPLY" =~ ^[Yy] ]]; then
    exit 0
  fi
fi

# 应用服务端补丁
echo ""
echo "应用服务端补丁..."
node "$SCRIPT_DIR/../patch/server-patch.js"
echo ""

# 提示客户端补丁
echo "=========================================="
echo "客户端补丁需要手动完成"
echo "=========================================="
echo ""
echo "客户端代码在浏览器中运行，无法通过 Node.js 补丁修改。"
echo ""
echo "选项："
echo "  1. 阅读 patch/client-patch-guide.md 手动修改客户端"
echo "  2. 使用变通方案（服务端推送 / HTTP API / 纯扩展）"
echo "  3. 向 pi-web 上游提交 PR（见 UPSTREAM.md）"
echo ""
echo "=========================================="
echo "应用完成！"
echo "还原补丁：bash $SCRIPT_DIR/revert-patch.sh"
echo "=========================================="
