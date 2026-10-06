#!/bin/bash
# pi-web-autocomplete 琛ヤ竵搴旂敤鑴氭湰
# 
# 鐢ㄦ硶锛歜ash apply-patch.sh
# 
# 鍔熻兘锛?#   1. 澶囦唤鍘熷 pi-web 缂栬瘧鏂囦欢
#   2. 搴旂敤鏈嶅姟绔ˉ涓侊紙monkey-patch锛?#   3. 鎻愮ず瀹㈡埛绔ˉ涓佹楠?
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# pi-web 缂栬瘧鏂囦欢璺緞
PI_WEB_DIR="${PI_WEB_DIR:-$HOME/.npm-global/lib/node_modules/@agegr/pi-web}"
SERVER_CHUNK="$PI_WEB_DIR/.next/server/chunks/6429.js"

echo "=========================================="
echo "pi-web-autocomplete 琛ヤ竵搴旂敤"
echo "=========================================="
echo ""

# 妫€鏌?pi-web 鏄惁瀛樺湪
if [ ! -f "$SERVER_CHUNK" ]; then
  echo "閿欒锛氭壘涓嶅埌 pi-web 缂栬瘧鏂囦欢"
  echo "  璺緞锛?SERVER_CHUNK"
  echo ""
  echo "璇疯缃?PI_WEB_DIR 鐜鍙橀噺锛屼緥濡傦細"
  echo "  export PI_WEB_DIR=\$(npm root -g)/@agegr/pi-web"
  exit 1
fi

echo "pi-web 鐩綍锛?PI_WEB_DIR"
echo "鏈嶅姟绔枃浠讹細$SERVER_CHUNK"
echo ""

# 妫€鏌ユ槸鍚﹀凡缁忓簲鐢ㄨ繃琛ヤ竵
BACKUP_FILE="$SERVER_CHUNK.bak"
if [ -f "$BACKUP_FILE" ]; then
  echo "璀﹀憡锛氬凡瀛樺湪澶囦唤鏂囦欢锛岃ˉ涓佸彲鑳藉凡搴旂敤"
  read -p "缁х画鍚楋紵(y/N) " -n 1
  echo
  if [[ ! "$REPLY" =~ ^[Yy] ]]; then
    exit 0
  fi
fi

# 搴旂敤鏈嶅姟绔ˉ涓?echo ""
echo "搴旂敤鏈嶅姟绔ˉ涓?.."
node "$SCRIPT_DIR/../patch/server-patch.cjs"
echo ""

# 鎻愮ず瀹㈡埛绔ˉ涓?echo "=========================================="
echo "瀹㈡埛绔ˉ涓侀渶瑕佹墜鍔ㄥ畬鎴?
echo "=========================================="
echo ""
echo "瀹㈡埛绔唬鐮佸湪娴忚鍣ㄤ腑杩愯锛屾棤娉曢€氳繃 Node.js 琛ヤ竵淇敼銆?
echo ""
echo "閫夐」锛?
echo "  1. 闃呰 patch/client-patch-guide.md 鎵嬪姩淇敼瀹㈡埛绔?
echo "  2. 浣跨敤鍙橀€氭柟妗堬紙鏈嶅姟绔帹閫?/ HTTP API / 绾墿灞曪級"
echo "  3. 鍚?pi-web 涓婃父鎻愪氦 PR锛堣 UPSTREAM.md锛?
echo ""
echo "=========================================="
echo "搴旂敤瀹屾垚锛?
echo "杩樺師琛ヤ竵锛歜ash $SCRIPT_DIR/revert-patch.sh"
echo "=========================================="

