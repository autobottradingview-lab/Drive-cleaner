# Drive Cleaner

A Claude skill that finds what is filling your Windows drive, shows you the full list of what is safe to delete and what must stay, and deletes only what you approve.

- Scans the whole drive (C by default): biggest folders, big files split into **new** (last N days, you choose) and **old**.
- Finds common junk: browser cache (Chrome, Edge, Brave), CapCut cache, Temp files, old app versions, updater caches, npm/pip cache, crash dumps, leftover Android emulators.
- Sorts everything into three lists: **delete ho sakta hai**, **aap ki marzi** (your own files) and **delete NAHI karna**, each with a plain reason.
- Deletes nothing until you say so. You approve item by item (`dlt`) or a whole section (`sb dlt`).
- Speaks your language. Works well in Roman Urdu / Hindi and English.

## Choose how to use it

| You have | Use | What happens |
|---|---|---|
| Claude Code or the Claude desktop app (Code tab) | [Option 1](#option-1-claude-code--claude-desktop) | Claude runs the scan and the cleanup for you |
| claude.ai with Skills | [Option 2](#option-2-claudeai-upload-the-skill) | Claude guides you, you run the commands it gives |
| Any other AI chat (Claude free, ChatGPT, Gemini...) | [Option 3](#option-3-any-ai-chat-no-skills) | Paste one prompt, then same guided steps |

---

### Option 1: Claude Code / Claude desktop

Copy the `drive-cleaner` folder into your skills folder:

```powershell
git clone https://github.com/autobottradingview-lab/drive-cleaner.git "$HOME\drive-cleaner-repo"
```
```powershell
Copy-Item "$HOME\drive-cleaner-repo\drive-cleaner" "$HOME\.claude\skills\drive-cleaner" -Recurse
```

No git? Click **Code > Download ZIP** on this page, extract it, and copy the inner `drive-cleaner` folder to `C:\Users\<you>\.claude\skills\`.

Then start a new chat and say: **"C drive full hai, scan karo"** or **"free up space on my C drive"**.

### Option 2: claude.ai (upload the skill)

1. Download [`drive-cleaner.zip`](https://github.com/autobottradingview-lab/drive-cleaner/raw/main/drive-cleaner.zip) from this repo.
2. In claude.ai open **Settings > Capabilities**, find **Skills**, and upload the ZIP. (Menu names can change a little; Skills must be available on your plan.)
3. Start a new chat: **"C drive full hai, 20 GB khali karna hai"**.

claude.ai cannot see your computer, so Claude will guide you: it tells you to download this repo's ZIP once, then gives you one command at a time and tells you exactly where to run it (normal PowerShell or Admin PowerShell). You paste the result back. The scan copies its report to your clipboard, so you just press Ctrl+V in the chat.

### Option 3: any AI chat (no skills)

Open [`PROMPT.md`](PROMPT.md), copy everything below the line, and paste it as your first message. Then describe your problem. The AI gives you the commands step by step.

---

## The scripts

Both scripts are plain PowerShell and work on Windows PowerShell 5.1 (built into Windows 10/11). You can read them before running.

**`scripts/scan.ps1`**: read-only, deletes nothing.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\drive-cleaner\scripts\scan.ps1 -Drive C -Days 30 -MinMB 300 -Copy
```

| Option | Meaning | Default |
|---|---|---|
| `-Drive` | Drive letter | `C` |
| `-Days` | Files changed in the last N days count as "new" | `30` |
| `-MinMB` | Smallest file size to list | `300` |
| `-Out` | Where to save the report | `%TEMP%\drive-cleaner-report.md` |
| `-Copy` | Also copy the report to the clipboard | off |

**`scripts/clean.ps1`**: deletes only what you pass to it, then shows how much space was freed.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\drive-cleaner\scripts\clean.ps1 -Paths "C:\path\one|C:\path\two" -BrowserCache "Chrome,Edge" -UserTemp -StopProcs "chrome"
```

| Option | Meaning |
|---|---|
| `-Paths` | Folders or files to delete, joined with `\|` |
| `-BrowserCache` | `Chrome`, `Edge`, `Brave`: clears only the cache folders in every profile (passwords, bookmarks and logins stay) |
| `-UserTemp` | Empties your Temp folder (files in use are skipped) |
| `-StopProcs` | Apps to close first so their files are not locked, joined with `,` |

Anything that needs Admin is reported as `LEFT` along with the command to run in an Admin PowerShell.

If Windows says the script is blocked, run this once in the extracted folder:

```powershell
Get-ChildItem -Recurse *.ps1 | Unblock-File
```

## What it never deletes

`C:\Windows` (including WinSxS; use Disk Cleanup for that), `pagefile.sys`, `Program Files` (uninstall apps from Settings instead), your browser profiles outside the cache, CapCut projects, installed tools like Python and Node. The full list with reasons is in [`drive-cleaner/references/safety-list.md`](drive-cleaner/references/safety-list.md).

## Roman Urdu quick guide

1. Is page par green **Code** button > **Download ZIP**. Downloads mein ZIP par right-click > **Extract All**.
2. Claude Code / desktop app hai to `drive-cleaner` folder ko `C:\Users\<aap>\.claude\skills\` mein copy karein aur chat mein likhein: "C drive full hai, scan karo".
3. Sirf claude.ai hai to `drive-cleaner.zip` ko Settings > Capabilities > Skills mein upload karein. Claude aap ko har command de ga aur bataye ga ke kahan chalani hai.
4. Koi aur AI chat hai to `PROMPT.md` ka text copy karke pehle message mein paste karein.
5. Claude poori list dikhaye ga. Jo cheez hatani ho us ke aage "dlt" likhein. Baqi sab waisa hi rahe ga.

## Safety

- Deleted files do not go to the Recycle Bin. Read the list before you approve.
- Close the browser or app before clearing its cache.
- Use at your own risk; see [LICENSE](LICENSE).

## Repo layout

```
drive-cleaner/            the skill (copy this folder)
  SKILL.md                instructions Claude follows
  scripts/scan.ps1        read-only scan
  scripts/clean.ps1       deletes approved items
  references/safety-list.md   what is safe / ask / never
  references/manual-mode.md   step-by-step guide mode for chats that cannot run commands
drive-cleaner.zip         the same folder zipped, for claude.ai upload
PROMPT.md                 paste-in prompt for any AI chat
```

## License

MIT
