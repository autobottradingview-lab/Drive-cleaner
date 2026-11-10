# Drive Cleaner scan. Read-only: lists sizes, deletes nothing.
# Works on Windows PowerShell 5.1 (no .NET Core APIs).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scan.ps1 -Drive C -Days 30 -MinMB 300 [-Out <report.md>] [-Copy]
# -Copy puts the whole report on the clipboard so it can be pasted into a chat.
param(
  [string]$Drive = 'C',
  [int]$Days = 30,
  [int]$MinMB = 300,
  [int]$FolderMinMB = 500,
  [string]$Out = "$env:TEMP\drive-cleaner-report.md",
  [switch]$Copy
)
$ErrorActionPreference = 'SilentlyContinue'
$root = "$($Drive.TrimEnd(':'))`:\"
$cutoff = (Get-Date).AddDays(-$Days)
$L = $env:LOCALAPPDATA

function Get-Size([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return -1 }
  $item = Get-Item -LiteralPath $path -Force
  if (-not $item.PSIsContainer) { return $item.Length }
  $sum = 0; $st = New-Object System.Collections.Generic.Stack[string]; $st.Push($path)
  while ($st.Count) {
    $di = New-Object System.IO.DirectoryInfo ($st.Pop())
    try { foreach ($s in $di.GetDirectories()) { if (-not ($s.Attributes -band 1024)) { $st.Push($s.FullName) } } } catch {}
    try { foreach ($f in $di.GetFiles()) { $sum += $f.Length } } catch {}
  }
  return $sum
}
function GB($b) { '{0:N2}' -f ($b / 1GB) }

# The packaged (MSIX) Claude app sees AppData\Local twice: the real files under
# Packages\<app>\LocalCache\Local and a merged view at AppData\Local. Skip the
# LocalCache copy when every folder in it also shows up in the merged view.
$skip = @{}
Get-ChildItem "$L\Packages" -Directory | ForEach-Object {
  foreach ($sub in 'Local', 'Roaming') {
    $lc = Join-Path $_.FullName "LocalCache\$sub"
    if (Test-Path $lc) {
      $view = if ($sub -eq 'Local') { $L } else { $env:APPDATA }
      $kids = @(Get-ChildItem $lc -Directory)
      if ($kids.Count -and -not ($kids | Where-Object { -not (Test-Path (Join-Path $view $_.Name)) })) { $skip[$lc.ToLower()] = $true }
    }
  }
}

# ---- full walk ----
$dirSizes = @{}; $big = New-Object System.Collections.Generic.List[object]
$st = New-Object System.Collections.Generic.Stack[string]; $st.Push($root)
while ($st.Count) {
  $d = $st.Pop(); $di = New-Object System.IO.DirectoryInfo $d
  try { foreach ($s in $di.GetDirectories()) { if (-not ($s.Attributes -band 1024) -and -not $skip.ContainsKey($s.FullName.ToLower())) { $st.Push($s.FullName) } } } catch {}
  try { $files = $di.GetFiles() } catch { continue }
  $sum = 0
  foreach ($f in $files) {
    $sum += $f.Length
    if ($f.Length -ge $MinMB * 1MB) {
      $big.Add([pscustomobject]@{ Bytes = $f.Length; Modified = $f.LastWriteTime; Created = $f.CreationTime; Path = $f.FullName })
    }
  }
  if (-not $sum) { continue }
  $parts = $d.TrimEnd('\').Split('\'); $acc = $parts[0]
  for ($i = 1; $i -lt [math]::Min($parts.Length, 7); $i++) { $acc += '\' + $parts[$i]; $dirSizes[$acc] += $sum }
}

$drv = Get-PSDrive $Drive.TrimEnd(':')
$r = New-Object System.Text.StringBuilder
function W($s) { [void]$r.AppendLine($s) }
W "# Drive Cleaner report: $root  ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
W ""
W "- Used: $(GB $drv.Used) GB, Free: $(GB $drv.Free) GB, Total: $(GB ($drv.Used + $drv.Free)) GB"
W "- New-file window: last $Days days (since $($cutoff.ToString('yyyy-MM-dd'))); big file = $MinMB MB+"
if ($skip.Count) { W "- Skipped $($skip.Count) duplicate app-package views (Packages\*\LocalCache), so sizes are not counted twice" }
W ""
W "## Big folders ($FolderMinMB MB+)"
W '```'
$dirSizes.GetEnumerator() | Where-Object { $_.Value -ge $FolderMinMB * 1MB } | Sort-Object Name | ForEach-Object { W ('{0,8} GB  {1}' -f (GB $_.Value), $_.Key) }
W '```'

$newer = $big | Where-Object { $_.Modified -ge $cutoff -or $_.Created -ge $cutoff } | Sort-Object Bytes -Descending
$older = $big | Where-Object { $_.Modified -lt $cutoff -and $_.Created -lt $cutoff } | Sort-Object Bytes -Descending
foreach ($sec in @(@("New big files (changed or created in last $Days days)", $newer), @("Old big files (older than $Days days)", $older))) {
  W ""; W "## $($sec[0])"; W ""; W "| GB | Modified | Created | Path |"; W "|---|---|---|---|"
  foreach ($b in $sec[1]) { W ("| {0} | {1:yyyy-MM-dd} | {2:yyyy-MM-dd} | {3} |" -f (GB $b.Bytes), $b.Modified, $b.Created, $b.Path) }
}

# ---- known junk / cleanup candidates ----
$cands = New-Object System.Collections.Generic.List[object]
function Add-C($name, $path, $kind, $note) { $s = Get-Size $path; if ($s -gt 5MB) { $cands.Add([pscustomobject]@{ Name = $name; GB = (GB $s); Kind = $kind; Path = $path; Note = $note }) } }
if ($Drive.TrimEnd(':') -eq $env:SystemDrive.TrimEnd(':')) {
  $tmp = (Get-ChildItem $env:TEMP -Force | Where-Object Name -ne 'claude' | ForEach-Object { Get-Size $_.FullName } | Measure-Object -Sum).Sum
  if ($tmp -gt 5MB) { $cands.Add([pscustomobject]@{ Name = 'User Temp files'; GB = (GB $tmp); Kind = 'cache'; Path = $env:TEMP; Note = 'skip the claude subfolder (in use)' }) }
  Add-C 'Windows Temp' "$env:windir\Temp" 'admin' ''
  Add-C 'Windows Update downloads' "$env:windir\SoftwareDistribution\Download" 'admin' 'stop wuauserv first or use Disk Cleanup'
  Add-C 'Recycle Bin' "$root`$Recycle.Bin" 'ask' 'Clear-RecycleBin -Force; cannot be undone'
  Add-C 'Crash dumps' "$L\CrashDumps" 'cache' ''
  Add-C 'Windows error reports' "$env:ProgramData\Microsoft\Windows\WER" 'admin' ''
  Add-C 'Delivery Optimization cache' "$env:windir\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" 'admin' ''
  Add-C 'Google Updater crx_cache' "${env:ProgramFiles(x86)}\Google\GoogleUpdater\crx_cache" 'admin' ''
  Add-C 'CapCut cache' "$L\CapCut\User Data\Cache" 'cache' 'projects stay safe; close CapCut first'
  Add-C 'npm cache' "$L\npm-cache" 'cache' ''
  Add-C 'pip cache' "$L\pip\cache" 'cache' ''
  Add-C 'Android emulator AVDs (.android)' "$env:USERPROFILE\.android" 'app' 'virtual phones; part of emulator removal'
  Add-C 'Android SDK' "$L\Android" 'app' 'emulator, system images, platform-tools'
  foreach ($base in "$env:APPDATA\Google", "$L\Google") { Get-ChildItem $base -Directory -Filter 'AndroidStudio*' | ForEach-Object { Add-C "Android Studio data $($_.Name)" $_.FullName 'app' '' } }
  Add-C 'Android Studio app' "$env:ProgramFiles\Android" 'app' 'uninstall from Settings > Apps first'
  Add-C 'Gradle cache' "$env:USERPROFILE\.gradle" 'app' 'only if no Android/Java projects'
  foreach ($b in @(@('Chrome', "$L\Google\Chrome\User Data"), @('Edge', "$L\Microsoft\Edge\User Data"), @('Brave', "$L\BraveSoftware\Brave-Browser\User Data"))) {
    if (Test-Path $b[1]) {
      $t = 0
      Get-ChildItem $b[1] -Directory | ForEach-Object { foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage') { $s = Get-Size (Join-Path $_.FullName $c); if ($s -gt 0) { $t += $s } } }
      if ($t -gt 5MB) { $cands.Add([pscustomobject]@{ Name = "$($b[0]) cache (all profiles)"; GB = (GB $t); Kind = 'cache'; Path = $b[1] + '\<profile>\{Cache,Code Cache,GPUCache,Service Worker\CacheStorage}'; Note = 'logins, passwords, bookmarks stay; close browser first' }) }
    }
  }
  Get-ChildItem "$L\Claude-Data\*\claude-code" -Directory | ForEach-Object {
    $vers = Get-ChildItem $_.FullName -Directory | Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending
    $vers | Select-Object -Skip 1 | ForEach-Object { Add-C "Old Claude Code version $($_.Name)" $_.FullName 'cache' 'newest version is kept' }
  }
  $dl = "$env:USERPROFILE\Downloads"; Add-C 'Downloads folder' $dl 'ask' 'user files: list big ones, never bulk delete'
  $hib = "$root" + 'hiberfil.sys'; if (Test-Path $hib -ErrorAction SilentlyContinue) { $cands.Add([pscustomobject]@{ Name = 'Hibernate file'; GB = (GB (Get-Item $hib -Force).Length); Kind = 'ask'; Path = $hib; Note = 'admin: powercfg -h off (turns off hibernate/fast startup)' }) }
}
W ""; W "## Cleanup candidates"; W ""; W "| Name | GB | Kind | Path | Note |"; W "|---|---|---|---|---|"
$cands | Sort-Object { [double]$_.GB } -Descending | ForEach-Object { W "| $($_.Name) | $($_.GB) | $($_.Kind) | $($_.Path) | $($_.Note) |" }

W ""; W "## Running processes that can lock files"
$procs = Get-Process | Where-Object { $_.Name -match '^(adb|emulator|qemu-system.*|CapCut|chrome|msedge|brave|studio64)$' } | Select-Object -ExpandProperty Name -Unique
W ($(if ($procs) { $procs -join ', ' } else { 'none' }))

[System.IO.File]::WriteAllText($Out, $r.ToString(), [System.Text.Encoding]::UTF8)
"Report saved: $Out"
if ($Copy) { Set-Clipboard -Value $r.ToString(); "Report copied. Paste it in the chat (Ctrl+V)." }
else { "Open it with: notepad `"$Out`"" }
