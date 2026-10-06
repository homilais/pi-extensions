# pi-web-autocomplete 补丁还原脚本 (Windows)
# 
# 用法：powershell -ExecutionPolicy Bypass -File revert-patch.ps1

$ErrorActionPreference = "Stop"

# pi-web 编译文件路径
$PiWebDir = if ($env:PI_WEB_DIR) { $env:PI_WEB_DIR } else { "$env:APPDATA\npm\ node_modules\@agegr\pi-web" }
$ServerChunk = Join-Path $PiWebDir ".next\server\chunks\6429.js"
$BackupFile = "$ServerChunk.bak"

Write-Host "=========================================="
Write-Host "pi-web-autocomplete 补丁还原"
Write-Host "=========================================="
Write-Host ""

if (-not (Test-Path $BackupFile)) {
    Write-Host "错误：找不到备份文件" -ForegroundColor Red
    Write-Host "  路径：$BackupFile"
    Write-Host "  可能补丁未应用，或已被删除"
    exit 1
}

Write-Host "备份文件：$BackupFile"
Write-Host "目标文件：$ServerChunk"
Write-Host ""

$answer = Read-Host "确认还原吗？(y/N)"
if ($answer -notmatch '^[Yy]') {
    Write-Host "已取消"
    exit 0
}

# 还原
Copy-Item -Path $BackupFile -Destination $ServerChunk -Force
Remove-Item -Path $BackupFile -Force

Write-Host ""
Write-Host "=========================================="
Write-Host "✓ 补丁已还原" -ForegroundColor Green
Write-Host "=========================================="
Write-Host ""
Write-Host "客户端代码未被修改（需要手动还原）"
