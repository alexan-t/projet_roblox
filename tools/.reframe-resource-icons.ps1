Add-Type -AssemblyName System.Drawing
Get-ChildItem assets/icons/resources/*.png | Where-Object { [int]$_.BaseName.Substring(9) -ge 11 } | ForEach-Object {
 $id=$_.BaseName
 $source="automation/screenshots/resources/$id-studio.jpg"
 $b=[Drawing.Bitmap]::FromFile((Join-Path (Get-Location) $source))
 $minX=$b.Width; $minY=$b.Height; $maxX=0; $maxY=0
 for($y=0;$y -lt $b.Height;$y++){for($x=0;$x -lt $b.Width;$x++){
  $c=$b.GetPixel($x,$y)
  if(-not ($c.R -gt $c.G+50 -and $c.B -gt $c.G+50 -and $c.R -gt 130 -and $c.B -gt 130)){
   $minX=[Math]::Min($minX,$x); $minY=[Math]::Min($minY,$y); $maxX=[Math]::Max($maxX,$x); $maxY=[Math]::Max($maxY,$y)
  }
 }}
 $size=[Math]::Min($b.Height,[Math]::Ceiling([Math]::Max($maxX-$minX+1,$maxY-$minY+1)/.78))
 $cx=[int][Math]::Max(0,[Math]::Min($b.Width-$size,($minX+$maxX-$size)/2))
 $cy=[int][Math]::Max(0,[Math]::Min($b.Height-$size,($minY+$maxY-$size)/2))
 $b.Dispose()
 & ./tools/export-resource-icon.ps1 -CapturePath $source -ResourceId $id -CropX $cx -CropY $cy -CropSize $size -ChromaKeyMagenta -Force
}
