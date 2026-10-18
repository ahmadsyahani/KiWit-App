param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$brandingDir = Join-Path $projectRoot 'assets\branding'
$resDir = Join-Path $projectRoot 'android\app\src\main\res'
$sourceFile = Get-Item -LiteralPath $SourcePath
New-Item -ItemType Directory -Path $brandingDir -Force | Out-Null
Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $brandingDir 'kiwit-logo-original.png')

function Save-LogoIcon {
    param([int]$Size, [double]$LogoScale, [bool]$Adaptive, [string]$Destination)
    $canvas = [System.Drawing.Bitmap]::new($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        if ($Adaptive) {
            $graphics.Clear([System.Drawing.Color]::Transparent)
        } else {
            $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F8F9FB'))
        }
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = ($Size * $LogoScale) / [Math]::Max($logoBounds.Width, $logoBounds.Height)
        if ($Adaptive) {
            # Keep the full logo inside the central safe circle of a 108dp layer.
            $diagonal = [Math]::Sqrt($logoBounds.Width * $logoBounds.Width + $logoBounds.Height * $logoBounds.Height)
            $scale = [Math]::Min($scale, ($Size * 64.0 / 108.0) / $diagonal)
        }
        $width = [single]($logoBounds.Width * $scale)
        $height = [single]($logoBounds.Height * $scale)
        $target = [System.Drawing.RectangleF]::new(($Size - $width) / 2, ($Size - $height) / 2, $width, $height)
        $graphics.DrawImage($source, $target, $logoBounds, [System.Drawing.GraphicsUnit]::Pixel)
        $canvas.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $canvas.Dispose()
    }
}

$source = [System.Drawing.Bitmap]::new($sourceFile.FullName)
try {
    # Locate the green artwork to remove only the large empty outer margins.
    $left = $source.Width
    $top = $source.Height
    $right = -1
    $bottom = -1
    for ($y = 0; $y -lt $source.Height; $y += 2) {
        for ($x = 0; $x -lt $source.Width; $x += 2) {
            $pixel = $source.GetPixel($x, $y)
            if ($pixel.A -gt 0 -and $pixel.G -gt $pixel.R + 12 -and $pixel.G -gt $pixel.B + 12) {
                $left = [Math]::Min($left, $x)
                $top = [Math]::Min($top, $y)
                $right = [Math]::Max($right, $x)
                $bottom = [Math]::Max($bottom, $y)
            }
        }
    }
    if ($right -lt $left) { throw 'Logo hijau tidak ditemukan pada gambar sumber.' }
    $left = [Math]::Max(0, $left - 4)
    $top = [Math]::Max(0, $top - 4)
    $right = [Math]::Min($source.Width - 1, $right + 4)
    $bottom = [Math]::Min($source.Height - 1, $bottom + 4)
    $logoBounds = [System.Drawing.RectangleF]::new($left, $top, $right - $left + 1, $bottom - $top + 1)

    $densities = @(
        @{ Name = 'mdpi'; Size = 48; Layer = 108 },
        @{ Name = 'hdpi'; Size = 72; Layer = 162 },
        @{ Name = 'xhdpi'; Size = 96; Layer = 216 },
        @{ Name = 'xxhdpi'; Size = 144; Layer = 324 },
        @{ Name = 'xxxhdpi'; Size = 192; Layer = 432 }
    )
    foreach ($density in $densities) {
        $directory = Join-Path $resDir ('mipmap-' + $density.Name)
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Save-LogoIcon -Size $density.Size -LogoScale 0.72 -Adaptive $false -Destination (Join-Path $directory 'ic_kiwit.png')
        Save-LogoIcon -Size $density.Layer -LogoScale (60.0 / 108.0) -Adaptive $true -Destination (Join-Path $directory 'ic_kiwit_foreground.png')
    }
    Save-LogoIcon -Size 512 -LogoScale 0.72 -Adaptive $false -Destination (Join-Path $brandingDir 'kiwit-launcher-preview.png')
    Write-Output 'Ikon KiWit dibuat untuk 5 kepadatan layar, termasuk adaptive icon Android.'
} finally {
    $source.Dispose()
}
