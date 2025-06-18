# Test script to verify path logic
param(
    [string]$WorldPath = "D:\data\.minecraft\world",
    [string]$WorldName = "world"
)

Write-Host "Testing path logic..." -ForegroundColor Cyan
Write-Host "Input WorldPath: $WorldPath" -ForegroundColor White
Write-Host "WorldName: $WorldName" -ForegroundColor White

# Test the logic
if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
    Write-Host "✅ Detected: User provided a world path directly" -ForegroundColor Green
    $actualWorldPath = $WorldPath
    Write-Host "Using world path: $actualWorldPath" -ForegroundColor Green
} else {
    Write-Host "❌ Detected: User provided a minecraft home path" -ForegroundColor Yellow
    $minecraftHomePath = $WorldPath
    Write-Host "Minecraft home path: $minecraftHomePath" -ForegroundColor Yellow
    # This would call Get-WorldPath function
}

Write-Host "Test completed!" -ForegroundColor Cyan 