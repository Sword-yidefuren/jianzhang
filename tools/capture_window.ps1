param(
  [string]$ProcessName = "jianzhang",
  [string]$OutputPath = "docs/screenshots/home.png"
)

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WindowCapture {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);

  public static IntPtr FindLargestWindow(int processId) {
    IntPtr best = IntPtr.Zero;
    long bestArea = 0;
    EnumWindows((hWnd, lParam) => {
      uint pid;
      GetWindowThreadProcessId(hWnd, out pid);
      if (pid != processId || !IsWindowVisible(hWnd)) return true;
      RECT rect;
      if (!GetWindowRect(hWnd, out rect)) return true;
      long area = (long)(rect.Right - rect.Left) * (rect.Bottom - rect.Top);
      if (area > bestArea) { bestArea = area; best = hWnd; }
      return true;
    }, IntPtr.Zero);
    return best;
  }
}
'@

$processes = @(Get-Process -Name $ProcessName -ErrorAction Stop)
[WindowCapture]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
foreach ($process in $processes) {
  if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
    [WindowCapture]::ShowWindow($process.MainWindowHandle, 9) | Out-Null
  }
}
Start-Sleep -Milliseconds 700
$handle = [IntPtr]::Zero
foreach ($process in $processes) {
  $candidate = [WindowCapture]::FindLargestWindow($process.Id)
  if ($candidate -ne [IntPtr]::Zero) {
    $rect = New-Object WindowCapture+RECT
    [WindowCapture]::GetWindowRect($candidate, [ref]$rect) | Out-Null
    if (($rect.Right - $rect.Left) -gt 200) { $handle = $candidate; break }
  }
}
if ($handle -eq [IntPtr]::Zero) { throw "No visible app window found" }

$rect = New-Object WindowCapture+RECT
[WindowCapture]::GetWindowRect($handle, [ref]$rect) | Out-Null
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) { throw "Window has no size" }

$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$hdc = $graphics.GetHdc()
$ok = [WindowCapture]::PrintWindow($handle, $hdc, 2)
$graphics.ReleaseHdc($hdc)
$graphics.Dispose()

$directory = Split-Path -Parent $OutputPath
if ($directory -and -not (Test-Path $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$absolute = Join-Path (Get-Location).Path $OutputPath
$bitmap.Save($absolute, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

Write-Output "PrintWindow=$ok size=${width}x${height} dpi=$([WindowCapture]::GetDpiForWindow($handle)) path=$absolute"

