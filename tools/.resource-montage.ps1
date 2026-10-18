Add-Type -AssemblyName System.Drawing
$files=Get-ChildItem assets/icons/resources/*.png | Sort-Object Name
$canvas=New-Object Drawing.Bitmap 900,900
$g=[Drawing.Graphics]::FromImage($canvas)
$g.Clear([Drawing.Color]::FromArgb(243,230,200))
$font=New-Object Drawing.Font 'Arial',10
$i=0
foreach($f in $files){
 $im=[Drawing.Image]::FromFile($f.FullName)
 if($im.Width -ne 512 -or $im.Height -ne 512){throw "Invalid size: $($f.Name)"}
 $x=($i%5)*180; $y=[Math]::Floor($i/5)*150
 $g.DrawString($f.BaseName,$font,[Drawing.Brushes]::Black,$x+5,$y+5)
 $g.DrawImage($im,[Drawing.Rectangle]::new($x+5,$y+30,96,96))
 $g.DrawImage($im,[Drawing.Rectangle]::new($x+120,$y+60,32,32))
 $im.Dispose(); $i++
}
$canvas.Save((Join-Path (Get-Location) 'automation/screenshots/resources/delivered-readability.png'),[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $font.Dispose(); $canvas.Dispose()
"PNG size checks: $i passed"
