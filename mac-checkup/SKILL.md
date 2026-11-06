---
name: "mac-checkup"
description: "Run a Mac maintenance checkup (health, startup, storage, unused apps, intruder scan, backups), update a Mac Checkup dashboard, and carry out only the fixes the user approves there. Use when the user says mac checkup, FIX, fix my computer, run my approved fixes, or asks why their Mac is slow, full, or unsafe."
---

# Mac Checkup

Setup: fill in your Mac's device name, home folder and iCloud plan here on first run.
Dashboard: a hand built Claude artifact page with the db capability (root rule read view, write admin). Create it on the first run and save its URL here.

**Always end every run by showing them the dashboard:** after writing the new data, call the Artifact tool with `action: "open"` and the dashboard URL. That puts the updated dashboard in front of them. Do this every time, for both Mode A and Mode B.

Golden rules: the scan is read only. Nothing on their Mac is removed, moved, or changed unless they ticked it on the dashboard and sent it, or approved it in chat. Never permanently delete: removals go to the Trash, and they empty the Trash themselves. Ask before creating or overwriting files on their Mac.

## How Claude reaches the Mac
- Claude can't type in Terminal (click only, a platform safety rule; never work around it). device_bash is a Linux VM that only sees granted folders, and ~/Library is blocked. Scanning big folders over the bridge times out.
- **Scans run by themselves.** The user installs a LaunchAgent, `com.user.maccheckup.scan`. When Claude creates `~/Mac Checkup/run-scan`, it checks that collect.command's md5 matches the hash saved in the helper, refuses if not, copies any existing raw file to `raw-YYYY-MM-prev-DDHHMM.txt`, runs the collector, and writes `scan-status.txt` (running / done / refused). The md5 lock means Claude can't change what it runs; only the user can, by reinstalling.
- **Fixes still need their double click.** Anything that moves or removes files is a `fix-YYYY-MM-DD.command` they run themselves.
- Wait for them with AskUserQuestion (Done / Got an error) whenever they have to do something.

## Dashboard data (ArtifactData on the URL above)
- `checkup/current`: {scanned, scanId, rows[]}. scanId is "YYYY-MM", plus "-rN" for extra scans in the same month. Each row has section, item, value (number|null), unit, status, detail, location, rank. Sections: run, disk (Free space, Used space, Total), usage, health, storage, startup, apps, security, backup. Status words: ok warn bad safe keep decide optional dead yours remove consider attention threat. Only use threat when confirmed.
- `checkup/fixes`: {scanId, items[]}. Each item has id, group, title, gb|null, detail, paths[], options ("delete", "icloud", "do"), how ("auto" Claude's script does it, "admin" script asks their Mac password, "manual" Claude walks them through), recommended, order. Groups in order: Clear caches, Move to iCloud, Your files, Uninstall apps, Startup cleanup, Security, Backup, Health. Caches only get delete. Their own data gets icloud (shown as Move to iCloud) and delete. Drop fixes that are done; keep ids stable.
- `checkup/approvals`: written by the page. {scanId, choices {fixId: "icloud"|"delete"|"do"} (treat an old "backup" as "icloud"), status "draft"|"submitted"|"done", submittedAt}. After a new scan, set its scanId to the new one with choices {} and status draft.
- `checkup/results`: written by Claude. {ranAt, items {fixId: {status "done"|"failed", note}}}. Reset to {} on a new scan.
Always read a doc first (or use the version from your last write) and pass if_version; they edit approvals live, so expect version bumps. Write current, fixes and approvals in one ArtifactData batch.

## Mode A: "run my mac checkup" / FIX
1. device_request_folder_access for ~ and /Applications if not granted.
2. device_bash: `touch "$HOME/mnt/<home folder>/Mac Checkup/run-scan"`, then poll scan-status.txt every 10 s until it says done or refused and run-scan is gone. A scan takes about 2 min; one device_bash call can run about 175 s, so poll inside the call and print the key sections in the same call.
   - refused: collect.command doesn't match. Tell the user; don't edit the helper.
   - no status after about 30 s: the helper isn't loaded. Fall back to asking them to double click collect.command.
3. Coverage gap: under launchd, macOS blocks zsh from Downloads, Desktop, Documents and Pictures, so HOME_FOLDERS, OLD_DOWNLOADS and INSTALLERS come back empty for those. Reuse the last double click values (mark them "from last scan"). A health row "Scan coverage" says so. If they want full coverage, they can double click collect.command once, or add /bin/zsh to Full Disk Access themselves (that gives every zsh script that access, so it's their call).
4. Read `raw-YYYY-MM.txt` section by section using awk on the `===== NAME =====` headers. Compare with the previous scan. Note: Spotlight's LARGE_FILES can lag behind; trust du in APP_SUPPORT and LIBRARY_FOLDERS.
5. Write `checkup/current` and `checkup/fixes` with the new scanId, reset results, and point approvals at the new scanId.
6. Open the dashboard (Artifact action open).
7. Reply: what changed since the last scan, what still needs attention, and one next step.

## Changing the collector (rare)
If collect.command must change: write the new script (ask first), compute its md5, regenerate `~/Mac Checkup/com.user.maccheckup.scan.plist` with python plistlib (Label com.user.maccheckup.scan, ProgramArguments `/bin/zsh -c <helper script with the new md5>`, WatchPaths `<home>/Mac Checkup/run-scan`, RunAtLoad false). They reinstall with: `launchctl bootout gui/$(id -u)/com.user.maccheckup.scan; cp ~/"Mac Checkup"/com.user.maccheckup.scan.plist ~/Library/LaunchAgents/ && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.maccheckup.scan.plist && echo Installed`. The helper script: exit unless run-scan exists; mkdir `.scan-lock` or exit; rm run-scan; compare `/sbin/md5 -q collect.command` to the hash or write "refused" and exit; copy existing raw to raw-YYYY-MM-prev-DDHHMM.txt; write running; run collect.command; write done; rmdir lock.

## Mode B: "run my approved fixes"
1. Read `checkup/approvals`. It needs status submitted and a scanId matching fixes. Otherwise tell them to tick and send first. Read `checkup/fixes`.
2. Build `~/Mac Checkup/fix-YYYY-MM-DD.command` from only the approved ids. The script pattern:
   - Start with `setopt NULL_GLOB` and `LOG="$HOME/Mac Checkup/fix-results.txt"; : > "$LOG"`, plus helpers ok/bad that log `id|done|label` or `id|failed|label`. Set `ICD=~/Library/Mobile\ Documents/com~apple~CloudDocs`.
   - Before working, for each related app that's running (pgrep), ask them to quit it and press Return. Chrome and Spotify need this for their caches.
   - delete: send the path to the Trash through Finder (`osascript -e 'on run a' -e 'tell application "Finder" to delete (POSIX file (item 1 of a) as alias)' -e 'end run' "$path"`), so Put Back works and root owned apps prompt for their password. A missing path counts as already gone. Never use rm. For d_downloads, use `find ~/Downloads -maxdepth 1 -mtime +90`. For installers, name the exact files from the scan.
   - icloud (Move to iCloud): `mkdir -p "$ICD/Mac Checkup Backups/YYYY-MM-DD"` and `mv` the item there (same disk, instant; iCloud uploads it, and Optimize Mac Storage evicts it later).
   - i_downloads: `mv -n` everything in ~/Downloads into `$ICD/Downloads`, logging skipped name clashes.
   - b_dev: `ditto -c -k --keepParent ~/Developer "$ICD/Mac Checkup Backups/Developer-YYYY-MM-DD.zip"`. Nothing gets removed.
   - admin items: `sudo -v` once (the user types their own password), then `sudo mv` plists and plugin to the Trash and `sudo launchctl bootout` where loaded.
   - manual items (Chrome extensions, Chrome on device AI, Spotify downloads, Time Machine, updates, restart, iCloud settings): not in the script. Give exact click steps, or with their OK use computer use on Chrome or System Settings (never Terminal). Say which Chrome profile an extension is in.
   - End with `df -h /System/Volumes/Data` before and after in the log, then echo Done.
3. Show them the plain words list of what the script will do, and flag anything that removes an app or their own data (for example, an app support folder that is really the app itself). Get a final OK, write the script, and they double click it. macOS asks once to let Terminal control Finder; they click OK.
4. Read fix-results.txt, write `checkup/results`, set approvals status to "done", and open the dashboard (Artifact action open).
5. Tell them to empty the Trash to actually free the space, then offer "run my mac checkup" to refresh. Estimates run high, because caches start refilling right away (in testing, about 29 GB estimated and 21 GB actually freed). Some freed space only shows after a few minutes or a restart.

## Collector
The read only collector lives in `collect.command` next to this file. It lists and measures and changes nothing. Its output sections are headed `===== NAME =====`.

## Analysis notes
1. Health: under 15% free is urgent (goal about 37 GB free). Spotlight at high CPU after updates is normal. Flag swap over 3 GB, battery under 80%, and pending updates.
2. Startup: verdicts are keep, optional, dead (ORPHAN or obsolete, like the Java plugin), and yours. local.* agents and com.user.maccheckup.scan are their own.
3. Storage: caches that rebuild are safe. Chrome's OptGuideOnDeviceModel (about 4 GB) is Chrome's on device AI and can be turned off in Chrome settings. Claude vm_bundles is needed for Cowork, so keep it. Games, Spotify downloads, and Xcode are their call; offer Move to iCloud for their own data.
4. Apps: use "prefs last touched" because Spotlight last used is often null.
5. Intruder: no threat claims without evidence. Free VPN and "scan and solve" extensions are attention. Recheck that removed extensions are really gone, since they live per Chrome profile.
6. Backup: check for Time Machine and whether iCloud syncs Desktop and Documents. iCloud is sync, not a full backup.

## Monthly
With their OK, create_trigger with requires_local_device true and cron `CRON_TZ=<your time zone> 37 10 1 * *`. Its prompt: use the mac-checkup skill Mode A (trigger the auto scan, analyze, update and open the dashboard) and send a short What changed / Needs attention / Can wait summary. The Mac must be on with the Claude app open.

## Chat style
Short, bold labels, casual, no dashes as punctuation. One next step at the end.