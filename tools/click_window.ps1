param(
  [int]$RelX,
  [int]$RelY,
  [string]$ProcessName = "jianzhang"
)

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WindowClick {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

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
[WindowClick]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
foreach ($process in $processes) {
  if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
    [WindowClick]::ShowWindow($process.MainWindowHandle, 9) | Out-Null
  }
}
Start-Sleep -Milliseconds 700
$handle = [IntPtr]::Zero
foreach ($process in $processes) {
  $candidate = [WindowClick]::FindLargestWindow($process.Id)
  if ($candidate -ne [IntPtr]::Zero) {
    $rect = New-Object WindowClick+RECT
    [WindowClick]::GetWindowRect($candidate, [ref]$rect) | Out-Null
    if (($rect.Right - $rect.Left) -gt 200) { $handle = $candidate; break }
  }
}
if ($handle -eq [IntPtr]::Zero) { throw "No visible app window found" }

$rect = New-Object WindowClick+RECT
[WindowClick]::GetWindowRect($handle, [ref]$rect) | Out-Null
[WindowClick]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Milliseconds 300
$x = $rect.Left + $RelX
$y = $rect.Top + $RelY
[WindowClick]::SetCursorPos($x, $y) | Out-Null
Start-Sleep -Milliseconds 120
[WindowClick]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[WindowClick]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
Write-Output "clicked $x,$y"

