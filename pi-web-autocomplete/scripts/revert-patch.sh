#!/bin/bash
# pi-web-autocomplete 补丁还原脚本
# 
# 用法：bash revert-patch.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_WEB_DIR="${PI_WEB_DIR:-$HOME/.npm-global/lib/node_modules/@agegr/pi-web}"
SERVER_CHUNK="$PI_WEB_DIR/.next/server/chunks/6429.js"
BACKUP_FILE="$SERVER_CHUNK.bak"

echo "=========================================="
echo "pi-web-autocomplete 补丁还原"
echo "=========================================="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "错误：找不到备份文件"
  echo "  路径：$BACKUP_FILE"
  echo "  可能补丁未应用，或已被删除"
  exit 1
fi

echo "备份文件：$BACKUP_FILE"
echo "目标文件：$SERVER_CHUNK"
echo ""

read -p "确认还原吗？(y/N) " -n 1
echo
if [[ ! "$REPLY" =~ ^[Yy] ]]; then
  echo "已取消"
  exit 0
fi

# 还原
cp "$BACKUP_FILE" "$SERVER_CHUNK"
rm -f "$BACKUP_FILE"

echo ""
echo "=========================================="
echo "✓ 补丁已还原"
echo "=========================================="
echo ""
echo "客户端代码未被修改（需要手动还原）"
