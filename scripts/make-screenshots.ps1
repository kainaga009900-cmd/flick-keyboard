# 使い方: powershell -ExecutionPolicy Bypass -File scripts/make-screenshots.ps1 -InputDir <スクショのフォルダ>
# 縦横比を保って 1290x2796 に収め、余白は白で埋める。出力は <InputDir>\appstore\
param([Parameter(Mandatory = $true)][string]$InputDir)
Add-Type -AssemblyName System.Drawing
$outDir = Join-Path $InputDir "appstore"
New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem -LiteralPath $InputDir -File | Where-Object { $_.Extension -in ".png", ".jpg", ".jpeg" } | ForEach-Object {
    $src = [System.Drawing.Image]::FromFile($_.FullName)
    $W = 1290; $H = 2796
    $scale = [Math]::Min($W / $src.Width, $H / $src.Height)
    $w = [int]($src.Width * $scale); $h = [int]($src.Height * $scale)
    $dst = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawImage($src, [int](($W - $w) / 2), [int](($H - $h) / 2), $w, $h)
    $out = Join-Path $outDir ($_.BaseName + ".png")
    $dst.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $dst.Dispose(); $src.Dispose()
    Write-Output "作りました: $out"
}