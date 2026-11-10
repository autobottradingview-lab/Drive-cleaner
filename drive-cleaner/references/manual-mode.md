# Guide mode: the user runs the commands

Use this when you cannot run PowerShell on the user's Windows PC yourself (claude.ai chat, the mobile app, another chatbot, or a cloud/Linux sandbox). Your sandbox is not their computer, so never scan or delete inside it and never present its results as their drive.

Your job here is to be a patient guide: give one step at a time, say exactly where to run it, wait for the user to paste the output back, then continue. Many users have never opened PowerShell, so spell things out.

## How to tell the user where to run things

Always name the window, and whether it needs Admin:

- **PowerShell (normal):** "Start button dabayein, `PowerShell` likhein, Enter dabayein." Use this for everything unless a step says Admin.
- **PowerShell (Admin):** "Start button dabayein, `PowerShell` likhein, phir *Run as administrator* par click karein, aur Yes dabayein." Use this only for items marked `admin`.
- **Settings > Apps:** for uninstalling installed programs (e.g. Android Studio).
- **Disk Cleanup:** "Start mein `Disk Cleanup` likhein, C chunein, phir *Clean up system files*." For Windows Update leftovers and WinSxS.

Put each command in its own code block so it can be copied in one click. Tell them: "Copy karein, PowerShell mein right-click karke paste karein, Enter dabayein."

## Step 0: get the scripts onto the PC

The scripts live in the GitHub repo. Ask the user to:

1. Open the repo page, click the green **Code** button, then **Download ZIP**.
2. Open the Downloads folder, right-click the ZIP, **Extract All**, then **Extract**.

Then this command finds the scripts wherever they were extracted and unblocks them (Windows blocks scripts that came from the internet):

```powershell
$dc = (Get-ChildItem "$HOME\Downloads" -Recurse -Filter scan.ps1 -ErrorAction SilentlyContinue | Select-Object -First 1).DirectoryName; Get-ChildItem $dc | Unblock-File; "Scripts yahan hain: $dc"
```

If it prints an empty path, the ZIP was not extracted; ask them to do step 2 again.

If the user can't download anything, fall back to the inline commands at the end of this file.

## Step 1: scan

Ask the 3 questions from SKILL.md first (days, GB target, any app to remove). Then give:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$dc\scan.ps1" -Drive C -Days 30 -MinMB 300 -Copy
```

Replace 30 with their days. Tell them it takes 1 to 5 minutes, and when it says "Report copied" they should come back to the chat and press Ctrl+V, then send.

Note: `$dc` only lives in that PowerShell window. If they closed it, they must run the Step 0 command again first. Say this whenever you give a later command.

## Step 2: the list

Build the full list exactly as SKILL.md section 3 describes, from the pasted report. Ask which items to delete.

## Step 3: delete

Build one `clean.ps1` command containing only the approved items, and say which window to use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$dc\clean.ps1" -Paths "C:\path\one|C:\path\two" -BrowserCache "Chrome" -UserTemp -StopProcs "chrome,CapCut"
```

- Use the real paths from their report; `|` joins paths, `,` joins names.
- Warn before `-StopProcs` closes their browser or app ("Chrome band ho jayega, koi zaroori tab ho to pehle save kar lein").
- Items marked admin: give a separate block and say "ye PowerShell (Admin) mein chalayein". They need the Step 0 line in that window too.
- App uninstalls: tell them to use Settings > Apps first, then delete the leftover folders.

Ask them to paste the output so you can confirm what was freed and what was left.

## Inline fallback (no download possible)

These do the most common jobs without the scripts. Give only the ones the user approved.

Free space:
```powershell
Get-PSDrive C | Select-Object @{n='Used GB';e={[math]::Round($_.Used/1GB,1)}},@{n='Free GB';e={[math]::Round($_.Free/1GB,1)}}
```

Biggest folders in the user profile:
```powershell
Get-ChildItem $HOME -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{GB=[math]::Round(((Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)/1GB,2); Folder=$_.FullName} } | Sort-Object GB -Descending | Select-Object -First 15 | Format-Table -AutoSize
```

Run the same command again with `$HOME\AppData\Local` instead of `$HOME` to look one level deeper.

Big files changed in the last N days (change 30 and 300):
```powershell
Get-ChildItem C:\Users -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 300MB -and $_.LastWriteTime -gt (Get-Date).AddDays(-30) } | Sort-Object Length -Descending | Select-Object @{n='GB';e={[math]::Round($_.Length/1GB,2)}},LastWriteTime,FullName | Format-Table -AutoSize
```

Browser cache, all Chrome profiles (close Chrome first):
```powershell
Get-ChildItem "$env:LOCALAPPDATA\Google\Chrome\User Data" -Directory | ForEach-Object { foreach($c in 'Cache','Code Cache','GPUCache'){ Remove-Item (Join-Path $_.FullName $c) -Recurse -Force -ErrorAction SilentlyContinue } }
```
(For Edge use `Microsoft\Edge\User Data`.)

User Temp files:
```powershell
Get-ChildItem $env:TEMP -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
```

A single folder the user approved:
```powershell
Remove-Item "C:\exact\path" -Recurse -Force
```
