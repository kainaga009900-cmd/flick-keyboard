# 1024x1024 の仮アイコン（緑の背景に白い「変」）を作る。App Store の決まりで透明（アルファ）なしの PNG にする。
param([string]$Out = "App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$bmp = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(29, 158, 117))
$font = New-Object System.Drawing.Font("Yu Gothic UI", 560, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$rect = New-Object System.Drawing.RectangleF 0, 0, 1024, 1024
$g.DrawString("変", $font, [System.Drawing.Brushes]::White, $rect, $format)
$bmp.Save((Resolve-Path -LiteralPath (Split-Path $Out)).Path + "\" + (Split-Path $Out -Leaf), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "作りました: $Out"
