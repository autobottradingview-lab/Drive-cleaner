# Drive Cleaner delete step. Run ONLY with paths the user approved.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File clean.ps1 -Paths "C:\a|C:\b" [-BrowserCache "Chrome,Edge"] [-UserTemp] [-StopProcs "adb,CapCut"]
# With -File, PowerShell passes a list as one string, so paths are joined with | (not allowed in Windows names).
param(
  [string]$Paths = '',
  [string]$BrowserCache = '',
  [switch]$UserTemp,
  [string]$StopProcs = ''
)
$ErrorActionPreference = 'SilentlyContinue'
$PathList = @($Paths -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$BrowserList = @($BrowserCache -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -in 'Chrome', 'Edge', 'Brave' })
$ProcList = @($StopProcs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$L = $env:LOCALAPPDATA
$before = (Get-PSDrive $env:SystemDrive.TrimEnd(':')).Free

foreach ($p in $ProcList) { Get-Process $p | Stop-Process -Force }
if ($ProcList) { Start-Sleep 2 }

$list = New-Object System.Collections.Generic.List[string]
$PathList | ForEach-Object { $list.Add($_) }
$roots = @{ Chrome = "$L\Google\Chrome\User Data"; Edge = "$L\Microsoft\Edge\User Data"; Brave = "$L\BraveSoftware\Brave-Browser\User Data" }
foreach ($b in $BrowserList) {
  Get-ChildItem $roots[$b] -Directory | ForEach-Object { foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage') { $x = Join-Path $_.FullName $c; if (Test-Path -LiteralPath $x) { $list.Add($x) } } }
}

$left = @()
foreach ($t in $list) {
  if (-not (Test-Path -LiteralPath $t)) { "not found: $t"; continue }
  Remove-Item -LiteralPath $t -Recurse -Force
  if (Test-Path -LiteralPath $t) { $left += $t; "LEFT (locked or needs admin): $t" } else { "deleted: $t" }
}
if ($UserTemp) {
  # the 'claude' subfolder holds the running session's files
  Get-ChildItem $env:TEMP -Force | Where-Object Name -ne 'claude' | Remove-Item -Recurse -Force
  "cleaned: $env:TEMP (files in use were skipped)"
}

$after = (Get-PSDrive $env:SystemDrive.TrimEnd(':')).Free
'Free before: {0:N1} GB | Free now: {1:N1} GB | Freed: {2:N1} GB' -f ($before / 1GB), ($after / 1GB), (($after - $before) / 1GB)
if ($left) { "Needs admin PowerShell:"; $left | ForEach-Object { "Remove-Item `"$_`" -Recurse -Force" } }
