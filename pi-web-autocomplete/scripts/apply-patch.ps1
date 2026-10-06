# pi-web-autocomplete 琛ヤ竵搴旂敤鑴氭湰 (Windows)
# 
# 鐢ㄦ硶锛歱owershell -ExecutionPolicy Bypass -File apply-patch.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectDir = Split-Path $ScriptDir -Parent

# pi-web 缂栬瘧鏂囦欢璺緞
$PiWebDir = if ($env:PI_WEB_DIR) { $env:PI_WEB_DIR } else { "$env:APPDATA\npm\node_modules\@agegr\pi-web" }
$ServerChunk = Join-Path $PiWebDir ".next\server\chunks\6429.js"

Write-Host "=========================================="
Write-Host "pi-web-autocomplete 琛ヤ竵搴旂敤"
Write-Host "=========================================="
Write-Host ""

# 妫€鏌?pi-web 鏄惁瀛樺湪
if (-not (Test-Path $ServerChunk)) {
    Write-Host "閿欒锛氭壘涓嶅埌 pi-web 缂栬瘧鏂囦欢" -ForegroundColor Red
    Write-Host "  璺緞锛?ServerChunk"
    Write-Host ""
    Write-Host "璇疯缃?PI_WEB_DIR 鐜鍙橀噺锛屼緥濡傦細" -ForegroundColor Yellow
    Write-Host "  `$env:PI_WEB_DIR = (npm root -g)\@agegr\pi-web"
    exit 1
}

Write-Host "pi-web 鐩綍锛?PiWebDir"
Write-Host "鏈嶅姟绔枃浠讹細$ServerChunk"
Write-Host ""

# 妫€鏌ユ槸鍚﹀凡缁忓簲鐢ㄨ繃琛ヤ竵
$BackupFile = "$ServerChunk.bak"
if (Test-Path $BackupFile) {
    Write-Host "璀﹀憡锛氬凡瀛樺湪澶囦唤鏂囦欢锛岃ˉ涓佸彲鑳藉凡搴旂敤" -ForegroundColor Yellow
    $answer = Read-Host "缁х画鍚楋紵(y/N)"
    if ($answer -notmatch '^[Yy]') { exit 0 }
}

# 搴旂敤鏈嶅姟绔ˉ涓?Write-Host ""
Write-Host "搴旂敤鏈嶅姟绔ˉ涓?.."
node (Join-Path $ProjectDir "patch\server-patch.cjs")
Write-Host ""

# 鎻愮ず瀹㈡埛绔ˉ涓?Write-Host "=========================================="
Write-Host "瀹㈡埛绔ˉ涓侀渶瑕佹墜鍔ㄥ畬鎴? -ForegroundColor Yellow
Write-Host "=========================================="
Write-Host ""
Write-Host "瀹㈡埛绔唬鐮佸湪娴忚鍣ㄤ腑杩愯锛屾棤娉曢€氳繃 Node.js 琛ヤ竵淇敼銆?
Write-Host ""
Write-Host "閫夐」锛?
Write-Host "  1. 闃呰 patch/client-patch-guide.md 鎵嬪姩淇敼瀹㈡埛绔?
Write-Host "  2. 浣跨敤鍙橀€氭柟妗堬紙鏈嶅姟绔帹閫?/ HTTP API / 绾墿灞曪級"
Write-Host "  3. 鍚?pi-web 涓婃父鎻愪氦 PR锛堣 UPSTREAM.md锛?
Write-Host ""
Write-Host "=========================================="
Write-Host "鉁?搴旂敤瀹屾垚锛? -ForegroundColor Green
Write-Host "杩樺師琛ヤ竵锛歱owershell -File scripts\revert-patch.ps1"
Write-Host "=========================================="

