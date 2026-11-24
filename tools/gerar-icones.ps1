# Builds the project's numbered account icons (icons/conta-1.ico ... conta-9.ico)
# and a preview sheet (icons/preview.png). Original artwork: a colored rounded
# square with a speech bubble and the account number. No Anthropic assets.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\gerar-icones.ps1
param([string]$Out = (Join-Path (Split-Path $PSScriptRoot) 'icons'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Same numbering and colors as claude-contas.ps1 ($CorNumero). 1 = main account.
$colors = @{ 1 = '#D97757'; 2 = '#2F6FED'; 3 = '#1E9E5A'; 4 = '#8E44CF'; 5 = '#C0392B'
                      6 = '#0E8C8C'; 7 = '#B7950B'; 8 = '#5D6D7E'; 9 = '#D63384' }

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Get-Shade([System.Drawing.Color]$c, [double]$f) {
    if ($f -ge 0) { $r = $c.R + (255 - $c.R) * $f; $g = $c.G + (255 - $c.G) * $f; $b = $c.B + (255 - $c.B) * $f }
    else { $r = $c.R * (1 + $f); $g = $c.G * (1 + $f); $b = $c.B * (1 + $f) }
    return [System.Drawing.Color]::FromArgb(255, [int]$r, [int]$g, [int]$b)
}

function New-IconBitmap([int]$size, [string]$hex, [int]$num) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.PixelOffsetMode = 'HighQuality'
    $s = [float]$size
    $m = [Math]::Max(0.5, $s * 0.03)
    # tile
    $tile = New-RoundRect $m $m ($s - 2 * $m) ($s - 2 * $m) ($s * 0.22)
    $rect = New-Object System.Drawing.RectangleF 0, 0, $s, $s
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (Get-Shade $c 0.18), (Get-Shade $c -0.12), 90
    $g.FillPath($grad, $tile)
    # speech bubble
    $bx = $s * 0.18; $by = $s * 0.20; $bw = $s * 0.64; $bh = $s * 0.50
    $bubble = New-RoundRect $bx $by $bw $bh ($s * 0.14)
    $tail = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tail.AddPolygon([System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF ($s * 0.30), ($by + $bh - 1)),
        (New-Object System.Drawing.PointF ($s * 0.46), ($by + $bh - 1)),
        (New-Object System.Drawing.PointF ($s * 0.26), ($s * 0.84))))
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $g.FillPath($white, $bubble); $g.FillPath($white, $tail)
    # number
    $font = New-Object System.Drawing.Font 'Segoe UI', ([float]($bh * 0.78)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    $numBrush = New-Object System.Drawing.SolidBrush (Get-Shade $c -0.10)
    $g.DrawString([string]$num, $font, $numBrush, (New-Object System.Drawing.RectangleF $bx, ($by + $bh * 0.04), $bw, $bh), $fmt)
    $g.Dispose()
    return $bmp
}

function Write-Ico([string]$path, $pngs) {
    $fs = [System.IO.File]::Create($path)
    $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$pngs.Count)
    $offset = 6 + 16 * $pngs.Count
    foreach ($p in $pngs) {
        $sz = $p[0]; $data = $p[1]; $b = if ($sz -ge 256) { 0 } else { $sz }
        $bw.Write([byte]$b); $bw.Write([byte]$b); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([UInt16]1); $bw.Write([UInt16]32); $bw.Write([UInt32]$data.Length); $bw.Write([UInt32]$offset)
        $offset += $data.Length
    }
    foreach ($p in $pngs) { $bw.Write([byte[]]$p[1]) }
    $bw.Close(); $fs.Close()
}

New-Item -ItemType Directory -Path $Out -Force | Out-Null
foreach ($n in 1..9) {
    $pngs = @()
    foreach ($size in 256, 64, 48, 32, 24, 16) {
        $bmp = New-IconBitmap $size $colors[$n] $n
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        $pngs += , @($size, $ms.ToArray())
    }
    Write-Ico (Join-Path $Out "conta-$n.ico") $pngs
}

# preview sheet
$cell = 150; $pad = 24
$sheet = New-Object System.Drawing.Bitmap ($colors.Count * $cell + 2 * $pad), ($cell + $pad + 36)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::Transparent)
$font = New-Object System.Drawing.Font 'Segoe UI', 13, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
$gray = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 120, 120, 120))
$i = 0
foreach ($n in 1..9) {
    $bmp = New-IconBitmap 128 $colors[$n] $n
    $x = $pad + $i * $cell + ($cell - 128) / 2
    $g.DrawImage($bmp, [int]$x, $pad, 128, 128); $bmp.Dispose()
    $label = if ($n -eq 1) { 'principal' } else { "conta $n" }
    $g.DrawString($label, $font, $gray, (New-Object System.Drawing.RectangleF ($pad + $i * $cell), ($pad + 134), $cell, 24), $fmt)
    $i++
}
$g.Dispose()
$sheet.Save((Join-Path $Out 'preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
Write-Host "icons written to $Out"
