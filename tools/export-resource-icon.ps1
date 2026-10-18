<#
.SYNOPSIS
Exporte une capture Studio en icône PNG 512 x 512, sans publier d'asset.
.DESCRIPTION
Recadrage carré explicite : contrôler le cadrage sur la capture avant l'export.
Conserve le canal alpha si la capture en possède un. Par défaut, le fond neutre
reste neutre. Avec -ChromaKeyMagenta, détoure le fond magenta de l'atelier et
cuit un contour Ink de 15 px de rayon (environ 6 % de largeur totale).
Ce mode exclut les objets magenta ; vérifier visuellement les bords après export.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CapturePath,
    [Parameter(Mandatory)][ValidatePattern('^resource_\d{3}$')][string]$ResourceId,
    [Parameter(Mandatory)][ValidateRange(0, 100000)][int]$CropX,
    [Parameter(Mandatory)][ValidateRange(0, 100000)][int]$CropY,
    [Parameter(Mandatory)][ValidateRange(1, 100000)][int]$CropSize,
    [switch]$ChromaKeyMagenta,
    [ValidateRange(0, 32)][int]$OutlinePixels = 15,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$catalogue = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'automation/catalogues/resources.json') | ConvertFrom-Json
if ($ResourceId -notin $catalogue.queue.id) { throw "Ressource hors catalogue : $ResourceId" }
$sourcePath = (Resolve-Path -LiteralPath $CapturePath).Path
$outputDirectory = Join-Path $repoRoot 'assets/icons/resources'
$outputPath = Join-Path $outputDirectory "$ResourceId.png"
if ((Test-Path -LiteralPath $outputPath) -and -not $Force) { throw "Le PNG existe déjà : $outputPath (utiliser -Force pour le remplacer)." }

Add-Type -AssemblyName System.Drawing
if ($ChromaKeyMagenta -and -not ('ResourceIconChroma' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
public static class ResourceIconChroma {
    public static Bitmap Apply(Bitmap input, int radius) {
        int w = input.Width, h = input.Height;
        var colors = new Color[w * h];
        var mask = new bool[w * h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            Color c = input.GetPixel(x, y);
            colors[y*w+x] = c;
            // Le fond magenta reste reconnaissable malgré la compression JPEG.
            // Ne pas confondre les ombres violettes du tissu avec le fond saturé.
            mask[y*w+x] = !(c.R > 200 && c.B > 200 && c.G < 80 && Math.Abs(c.R - c.B) < 60);
        }
        var expanded = (bool[])mask.Clone();
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            if (!mask[y*w+x]) continue;
            // Ne dilater que les pixels de bord.
            if (x > 0 && x < w-1 && y > 0 && y < h-1 &&
                mask[y*w+x-1] && mask[y*w+x+1] && mask[(y-1)*w+x] && mask[(y+1)*w+x]) continue;
            for (int dy = -radius; dy <= radius; dy++) {
                int yy = y + dy;
                if (yy < 0 || yy >= h) continue;
                int half = (int)Math.Sqrt(radius*radius - dy*dy);
                for (int dx = -half; dx <= half; dx++) {
                    int xx = x + dx;
                    if (xx >= 0 && xx < w) expanded[yy*w+xx] = true;
                }
            }
        }
        var output = new Bitmap(w, h, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            int i = y*w+x;
            bool edge = mask[i] && (x < 2 || y < 2 || x >= w-2 || y >= h-2 ||
                !mask[i-2] || !mask[i+2] || !mask[i-2*w] || !mask[i+2*w]);
            output.SetPixel(x, y, mask[i] && !edge ? colors[i] : expanded[i] ? Color.FromArgb(255,31,26,23) : Color.Transparent);
        }
        return output;
    }
}
'@
}
$source = $null
$bitmap = $null
$graphics = $null
try {
    $source = [Drawing.Image]::FromFile($sourcePath)
    if ($CropX + $CropSize -gt $source.Width -or $CropY + $CropSize -gt $source.Height) {
        throw "Recadrage hors capture ($($source.Width) x $($source.Height))."
    }
    $bitmap = New-Object Drawing.Bitmap 512, 512, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([Drawing.Color]::Transparent)
    $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $destination = New-Object Drawing.Rectangle 0, 0, 512, 512
    $crop = New-Object Drawing.Rectangle $CropX, $CropY, $CropSize, $CropSize
    $graphics.DrawImage($source, $destination, $crop, [Drawing.GraphicsUnit]::Pixel)
    if ($ChromaKeyMagenta) {
        $graphics.Dispose()
        $graphics = $null
        $keyed = [ResourceIconChroma]::Apply($bitmap, $OutlinePixels)
        $bitmap.Dispose()
        $bitmap = $keyed
    }
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $bitmap.Save($outputPath, [Drawing.Imaging.ImageFormat]::Png)
    Write-Output $outputPath
}
finally {
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
    if ($source) { $source.Dispose() }
}
