Add-Type -AssemblyName System.Drawing
$basePath = "C:\Users\omkar\OneDrive\Documents\ILGC_Prototype\Final\parcel_app"
$img = [System.Drawing.Image]::FromFile("$basePath\assets\logo.png")
$sizes = @{ "mdpi" = 48; "hdpi" = 72; "xhdpi" = 96; "xxhdpi" = 144; "xxxhdpi" = 192 }

foreach ($key in $sizes.Keys) {
    $size = $sizes[$key]
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $graph = [System.Drawing.Graphics]::FromImage($bmp)
    
    # High quality resizing
    $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graph.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graph.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graph.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $graph.DrawImage($img, 0, 0, $size, $size)
    
    $path = "$basePath\android\app\src\main\res\mipmap-$key\ic_launcher.png"
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # also overwrite ic_launcher_round if it exists
    $roundPath = "$basePath\android\app\src\main\res\mipmap-$key\ic_launcher_round.png"
    if (Test-Path $roundPath) {
        $bmp.Save($roundPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    $graph.Dispose()
    $bmp.Dispose()
}
$img.Dispose()
Write-Host "Icons generated successfully!"
