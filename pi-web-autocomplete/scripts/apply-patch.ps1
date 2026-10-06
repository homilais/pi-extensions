# pi-web-autocomplete 补丁应用脚本 (Windows)
# 
# 用法：powershell -ExecutionPolicy Bypass -File apply-patch.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectDir = Split-Path $ScriptDir -Parent

# pi-web 编译文件路径
$PiWebDir = if ($env:PI_WEB_DIR) { $env:PI_WEB_DIR } else { "$env:APPDATA\npm\node_modules\@agegr\pi-web" }
$ServerChunk = Join-Path $PiWebDir ".next\server\chunks\6429.js"

Write-Host "=========================================="
Write-Host "pi-web-autocomplete 补丁应用"
Write-Host "=========================================="
Write-Host ""

# 检查 pi-web 是否存在
if (-not (Test-Path $ServerChunk)) {
    Write-Host "错误：找不到 pi-web 编译文件" -ForegroundColor Red
    Write-Host "  路径：$ServerChunk"
    Write-Host ""
    Write-Host "请设置 PI_WEB_DIR 环境变量，例如：" -ForegroundColor Yellow
    Write-Host "  `$env:PI_WEB_DIR = (npm root -g)\@agegr\pi-web"
    exit 1
}

Write-Host "pi-web 目录：$PiWebDir"
Write-Host "服务端文件：$ServerChunk"
Write-Host ""

# 检查是否已经应用过补丁
$BackupFile = "$ServerChunk.bak"
if (Test-Path $BackupFile) {
    Write-Host "警告：已存在备份文件，补丁可能已应用" -ForegroundColor Yellow
    $answer = Read-Host "继续吗？(y/N)"
    if ($answer -notmatch '^[Yy]') { exit 0 }
}

# 应用服务端补丁
Write-Host ""
Write-Host "应用服务端补丁..."
node (Join-Path $ProjectDir "patch\server-patch.js")
Write-Host ""

# 提示客户端补丁
Write-Host "=========================================="
Write-Host "客户端补丁需要手动完成" -ForegroundColor Yellow
Write-Host "=========================================="
Write-Host ""
Write-Host "客户端代码在浏览器中运行，无法通过 Node.js 补丁修改。"
Write-Host ""
Write-Host "选项："
Write-Host "  1. 阅读 patch/client-patch-guide.md 手动修改客户端"
Write-Host "  2. 使用变通方案（服务端推送 / HTTP API / 纯扩展）"
Write-Host "  3. 向 pi-web 上游提交 PR（见 UPSTREAM.md）"
Write-Host ""
Write-Host "=========================================="
Write-Host "✓ 应用完成！" -ForegroundColor Green
Write-Host "还原补丁：powershell -File scripts\revert-patch.ps1"
Write-Host "=========================================="
