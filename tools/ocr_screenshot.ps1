param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime] | Out-Null

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and
  $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await($WinRtTask, $ResultType) {
  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
  $netTask = $asTask.Invoke($null, @($WinRtTask))
  $netTask.Wait(-1) | Out-Null
  $netTask.Result
}

$absolute = (Resolve-Path $Path).Path
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($absolute)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
$result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])

foreach ($line in $result.Lines) {
  $words = @($line.Words)
  if ($words.Count -eq 0) { continue }
  $left = [double]::MaxValue
  $top = [double]::MaxValue
  $right = [double]::MinValue
  $bottom = [double]::MinValue
  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($word in $words) {
    $rect = $word.BoundingRect
    $left = [math]::Min($left, $rect.X)
    $top = [math]::Min($top, $rect.Y)
    $right = [math]::Max($right, $rect.X + $rect.Width)
    $bottom = [math]::Max($bottom, $rect.Y + $rect.Height)
    $parts.Add($word.Text)
  }
  Write-Output ("[{0,4},{1,4} - {2,4},{3,4}] {4}" -f [int]$left, [int]$top, [int]$right, [int]$bottom, ($parts -join ''))
}
