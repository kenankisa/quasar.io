Add-Type -AssemblyName System.Drawing

$size = 1024
$cx = $size / 2.0
$cy = $size / 2.0
$format = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$bmp = New-Object System.Drawing.Bitmap($size, $size, $format)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

function Draw-GlowArc {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.RectangleF]$Rect,
        [int]$PenWidth,
        [System.Drawing.Color]$Color,
        [int]$GlowSteps = 8
    )

    for ($i = $GlowSteps; $i -ge 1; $i--) {
        $width = $PenWidth + ($i * 4)
        $alpha = [int](90 / ($i * 1.1))
        $glowColor = [System.Drawing.Color]::FromArgb($alpha, $Color.R, $Color.G, $Color.B)
        $glowPen = New-Object System.Drawing.Pen($glowColor, $width)
        $glowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $glowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $Graphics.DrawArc($glowPen, $Rect.X, $Rect.Y, $Rect.Width, $Rect.Height, 0, 360)
        $glowPen.Dispose()
    }

    $mainPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, $Color.R, $Color.G, $Color.B), $PenWidth)
    $mainPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $mainPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $Graphics.DrawArc($mainPen, $Rect.X, $Rect.Y, $Rect.Width, $Rect.Height, 0, 360)
    $mainPen.Dispose()
}

$cyan = [System.Drawing.Color]::FromArgb(255, 0, 240, 255)
$magenta = [System.Drawing.Color]::FromArgb(255, 255, 0, 170)

Draw-GlowArc -Graphics $g -Rect (New-Object System.Drawing.RectangleF(210, 210, 604, 604)) -PenWidth 26 -Color $cyan -GlowSteps 10
Draw-GlowArc -Graphics $g -Rect (New-Object System.Drawing.RectangleF(285, 285, 454, 454)) -PenWidth 9 -Color $magenta -GlowSteps 6

for ($i = 8; $i -ge 1; $i--) {
    $alpha = [int](70 / $i)
    $tailPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alpha, 255, 0, 170)), (18 + ($i * 3))
    $tailPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $tailPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($tailPen, 690, 690, 805, 805)
    $tailPen.Dispose()
}

$tailMain = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 0, 170)), 20
$tailMain.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$tailMain.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($tailMain, 690, 690, 805, 805)
$tailMain.Dispose()

$diskPen1 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210, 0, 240, 255)), 7
$g.DrawEllipse($diskPen1, 295, 395, 434, 180)
$diskPen1.Dispose()

$diskPen2 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, 255, 0, 170)), 4
$g.DrawEllipse($diskPen2, 320, 420, 384, 130)
$diskPen2.Dispose()

for ($r = 78; $r -ge 16; $r -= 8) {
    $alpha = [int](35 + ((78 - $r) * 1.2))
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha, 255, 255, 255))
    $g.FillEllipse($brush, ($cx - $r), ($cy - $r), ($r * 2), ($r * 2))
    $brush.Dispose()
}

$coreBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
$g.FillEllipse($coreBrush, ($cx - 16), ($cy - 16), 32, 32)
$coreBrush.Dispose()

$fontFamily = New-Object System.Drawing.FontFamily("Segoe UI")
$font = New-Object System.Drawing.Font($fontFamily, 168, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

$shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 0, 0, 0))
$g.DrawString("Q", $font, $shadowBrush, ($cx + 2), ($cy - 8 + 2), $sf)
$textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 240, 252, 255))
$g.DrawString("Q", $font, $textBrush, $cx, ($cy - 8), $sf)

$font.Dispose()
$fontFamily.Dispose()
$sf.Dispose()
$shadowBrush.Dispose()
$textBrush.Dispose()

$outDir = Join-Path $PSScriptRoot "..\assets\icon"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outPath = Join-Path $outDir "app_icon.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()

Write-Output "Saved: $outPath"
