---
name: drive-cleaner
description: Drive Cleaner for Windows. Scans a drive (C by default), finds the biggest folders and files, splits big files into new (last N days) and old, lists junk like browser cache, CapCut cache, Temp files, old app versions, updater caches and leftover Android emulators, then gives the user a full list of what is safe to delete and what must stay, and deletes only what the user approves. Runs the scan itself when it can use PowerShell on the PC, otherwise guides the user step by step with copy-paste commands. Use whenever the user says "C drive full hai", "drive scan karo", "space khali karna hai", "kaunsi files bari hain", "cache saaf karo", "faltu files hatao", "emulator uninstall karo", "my C drive is full", "free up disk space", "what is taking space", "clean my PC", "disk cleanup", "low disk space", or asks which files are eating storage, even if they don't say "Drive Cleaner".
---

# Drive Cleaner

Find what is filling a Windows drive, show the user the complete picture, and delete only what they approve.

Deleting is permanent, so everything here follows one rule: scan and explain first, delete second, and only the items the user said yes to.

Reply in the user's language. Many users write Roman Urdu/Hindi; answer them in simple Roman Urdu and keep English words only where they are the normal word (cache, Temp, GB, Admin). Assume the user is not technical.

## 0. Pick the mode

- **Auto mode:** you have a shell tool (PowerShell or Bash) that runs on the user's own Windows PC (e.g. Claude Code or the Claude desktop app). You run the scripts yourself.
- **Guide mode:** anything else: claude.ai chat, the mobile app, a Linux/cloud sandbox, another chatbot. You cannot see their drive. Read `references/manual-mode.md` now and follow it: you give one command at a time, say exactly which window to run it in, and the user pastes the output back.

When unsure, check: in auto mode `$env:OS` is `Windows_NT` and `Test-Path C:\Windows` is true. A sandbox that shows `/home` or `/mnt` is not their PC.

## 1. Ask before scanning

Ask once (with AskUserQuestion if you have it, otherwise as a short numbered message). Skip anything the user already said:

1. **Kitne din ka list chahiye?** Which big files count as "new". 7 days, 30 days (recommended), 90 days, 1 year.
2. **Kitna GB khali karna hai?** 10 GB, 25 GB, as much as possible. This tells you when the list is enough.
3. **Koi app hatani hai?** e.g. an emulator or a game. Default: no.

Drive is C unless the user names another.

## 2. Scan

`scripts/scan.ps1` is read-only. It lists sizes and deletes nothing. A full C scan takes 1 to 5 minutes, so give it a long timeout.

Auto mode:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\scan.ps1" -Drive C -Days <N> -MinMB 300 -Out "<temp-dir>\drive-report.md"
```
Then read the report file.

Guide mode: the user runs it with `-Copy` and pastes the report into the chat (see `references/manual-mode.md`).

The report has drive used/free, big folders (500 MB+), new big files, old big files, cleanup candidates with sizes, and apps that would lock files. The script already avoids counting the packaged Claude app's `Packages\*\LocalCache` copy twice and runs on Windows PowerShell 5.1, so don't redo those by hand.

If the user wants an app removed, look for all its traces: install folder, `AppData\Local`, `AppData\Roaming`, `%USERPROFILE%\.<app>`, downloads it left behind, running processes, the Settings > Apps entry, and user environment variables / Path entries.

## 3. Build the full list

Read `references/safety-list.md` and sort every item into it. Then reply with the complete list in this shape. Include every item over ~100 MB, not just the top few, because the user wants to see everything:

```
## Drive ka haal
C: X GB ka hai, Y GB bhara, Z GB khali. Target: T GB.

## Delete ho sakta hai (kul ~S GB)
| # | Kya hai | Size | Kab bana | Note |

## Bari files: pichle N din mein nayi
| Size | Date | File | Delete? (haan / nahi / aap ki marzi) |

## Bari files: N din se purani
(same table)

## Delete NAHI karna
- **Name (size):** reason in one line
```

- Give each row a reason a non-technical person understands ("ye cache hai, khud dobara ban jayega", "is mein aap ke passwords hain").
- Mark items that need Admin, and items whose app must be closed first.
- Say plainly if the target can't be reached without deleting the user's own files.
- The user's own work (videos, projects, documents) never goes under "delete ho sakta hai"; put it in the files table as "aap ki marzi".

End by asking which items to delete. Users often reply per item with "dlt", or "sb dlt" for a whole section. Each "dlt" approves that row only; anything not approved stays.

## 4. Delete the approved items

Use `scripts/clean.ps1` so deletion, locked files and the freed-space count work the same way every time:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\clean.ps1" -Paths "<path1>|<path2>" -BrowserCache "Chrome,Edge" -UserTemp -StopProcs "adb,emulator,CapCut"
```

- Join paths with `|` and names with `,`, each inside one quoted string (with `-File`, PowerShell doesn't split lists).
- `-BrowserCache` clears only each profile's cache folders, never the profile.
- `-StopProcs` closes apps that lock files. Stop only what the approved items need, and tell the user (e.g. Chrome will close).
- Paths that need Admin come back as "LEFT" with the exact command to run in an Admin PowerShell; pass that on.
- For an app removal, also clear leftover env variables, e.g. `[Environment]::SetEnvironmentVariable('ANDROID_HOME',$null,'User')`, and Path entries.

In guide mode, give the user this command to run instead (see `references/manual-mode.md`).

## 5. Report

Free space before and after, GB freed, what was deleted, what was left and why, and any Admin command still to run. Keep it short.
