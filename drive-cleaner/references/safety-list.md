# What to delete and what to keep

Use this to sort every item in the scan report into one of three lists. When something is not here, judge it by one question: if this disappears, does the user lose their own work, a login, or a working app? If yes, it goes in "keep" or "ask".

## A. Safe to delete (rebuilds itself, user loses nothing)

| Item | Path | Note |
|---|---|---|
| User Temp files | `%TEMP%` | Skip `%TEMP%\claude` (the running session) |
| Browser cache (Chrome, Edge, Brave) | `User Data\<profile>\Cache`, `Code Cache`, `GPUCache`, `Service Worker\CacheStorage` | Close the browser first. Logins, passwords, bookmarks, history and extensions stay. Sites load a bit slower the first time. |
| CapCut cache | `%LOCALAPPDATA%\CapCut\User Data\Cache` | Projects live elsewhere and stay. `SmartCrop` files are render copies of videos, not the originals. Close CapCut first. |
| Old Claude Code versions | `%LOCALAPPDATA%\Claude-Data\*\claude-code\<old version>` | Keep the newest version folder |
| Google Updater cache | `C:\Program Files (x86)\Google\GoogleUpdater\crx_cache` | Needs admin |
| npm / pip cache | `%LOCALAPPDATA%\npm-cache`, `%LOCALAPPDATA%\pip\cache` | Re-downloads when needed |
| Crash dumps, error reports | `%LOCALAPPDATA%\CrashDumps`, `%ProgramData%\Microsoft\Windows\WER` | WER needs admin |
| Windows Temp, Update downloads, Delivery Optimization | `C:\Windows\Temp`, `SoftwareDistribution\Download`, DeliveryOptimization cache | Needs admin; Disk Cleanup does these safely |
| Downloaded installer zips of an app being removed | e.g. `%LOCALAPPDATA%\Android\_downloads` | |

## B. Delete only when the user says so (apps, user files, settings)

| Item | Path | What the user loses |
|---|---|---|
| Android emulator (full removal) | `%USERPROFILE%\.android`, `%LOCALAPPDATA%\Android` (SDK, emulator, system-images, platform-tools, _downloads), `%APPDATA%\Google\AndroidStudio*`, `%LOCALAPPDATA%\Google\AndroidStudio*` | The virtual phones and everything in them. If Android Studio is installed (`C:\Program Files\Android`), uninstall it from Settings > Apps first. Stop `adb`, `emulator`, `qemu-system*` before deleting. Also clear the `ANDROID_HOME` / `ANDROID_SDK_ROOT` user variables and Path entries if they exist. |
| Gradle cache | `%USERPROFILE%\.gradle` | Only safe when no Android/Java projects are kept |
| Recycle Bin | `$Recycle.Bin` | Cannot be undone |
| Big files in Downloads, Desktop, Videos, Documents | | The user's own files. List them one by one; never bulk delete. |
| Hibernate file | `hiberfil.sys` | `powercfg -h off` (admin) turns off hibernate and fast startup |
| Caches of the user's own dev/AI tools | `.cache\huggingface` (AI models), `ms-playwright` (test browsers), other `%USERPROFILE%\.cache\*` | Tools re-download them, which is slow; ask first |

## C. Never delete (tell the user why)

| Item | Why |
|---|---|
| `C:\Windows`, `WinSxS`, `System32`, `DriverStore` | Windows breaks. WinSxS can only shrink through Disk Cleanup > "Clean up system files" or `DISM /Online /Cleanup-Image /StartComponentCleanup` (admin). |
| `pagefile.sys`, `swapfile.sys` | Windows virtual memory, in use |
| `Program Files`, `Program Files (x86)` app folders | Uninstall apps from Settings > Apps instead |
| Browser `User Data` outside the cache folders | Passwords, bookmarks, logins, extensions |
| CapCut `User Data` outside `Cache` | Projects, drafts, settings |
| `%USERPROFILE%\.claude`, `Claude-Data` (newest version), `AppData\Local\Packages\Claude_*` | Claude app, skills, memory |
| Python, Node, `AppData\Local\Programs` | Installed tools |
| Browser profiles made by other tools (`*\chrome-profile`) | Logins used by those tools |
| `ProgramData`, `Recovery`, `System Volume Information` | System |
