!/bin/zsh
# Mac Checkup collector v2. Read only: it lists and measures, it changes nothing.
setopt NULL_GLOB
D="$HOME/Mac Checkup"; mkdir -p "$D"; OUT="$D/raw-$(date +%Y-%m).txt"
s(){ printf '\n===== %s =====\n' "$1"; { printf '[%s] %s\n' "$(date +%T)" "$1" >/dev/tty; } 2>/dev/null; }
nz(){ grep -vE '^ *0B[[:space:]]'; }   # drop iCloud placeholders that show as 0B
echo "Mac Checkup running (read only, about 3 minutes)..."
{
s RUN_DATE; date
s SYSTEM; sw_vers; uptime; sysctl -n machdep.cpu.brand_string hw.memsize; ls /Users
s DISK; df -h /System/Volumes/Data; diskutil info /System/Volumes/Data | grep -E 'SMART|Free Space|Used Space|Container Total|Purgeable'
s LOCAL_SNAPSHOTS; tmutil listlocalsnapshots / 2>&1
s MEMORY; memory_pressure | tail -1; sysctl vm.swapusage
s TOP_CPU; ps -Ao pcpu,pmem,comm -r | head -15
s TOP_MEM; ps -Ao pmem,rss,comm -m | head -15
s BATTERY; system_profiler SPPowerDataType | grep -E 'Cycle Count|Condition|Maximum Capacity'
s UPDATES; softwareupdate -l 2>&1 | tail -12
s LOGIN_ITEMS; osascript -e 'tell application "System Events" to get the name of every login item' 2>&1
s LAUNCH_ITEMS; ls -la ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons 2>&1
s LAUNCHCTL_NON_APPLE; launchctl list | grep -v com.apple
s LAUNCH_ITEM_SIGNATURES
for p in ~/Library/LaunchAgents/*.plist /Library/LaunchAgents/*.plist /Library/LaunchDaemons/*.plist; do
  [[ -r "$p" ]] || { echo "$p -> (root only, not readable)"; continue; }
  b=$(/usr/libexec/PlistBuddy -c 'Print :Program' "$p" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$p" 2>/dev/null)
  [[ -z "$b" ]] && continue
  if [[ ! -e "$b" ]]; then echo "$p -> $b | ORPHAN (target missing)"; continue; fi
  echo "$p -> $b | $(codesign -dv "$b" 2>&1 | grep -E 'TeamIdentifier|not signed' | head -1)"
done
s LARGE_FILES; mdfind -onlyin ~ 'kMDItemFSSize > 500000000' 2>/dev/null | while IFS= read -r f; do du -sh "$f" 2>/dev/null; done | nz | sort -rh | head -25
s HOME_FOLDERS; du -sh ~/* ~/.[!.]* 2>/dev/null | sort -rh | head -25
s ICLOUD_LOCAL_SIZE; du -sh ~/Library/Mobile\ Documents 2>&1 | tail -1
s OTHER_TOP_LEVEL; du -sh /Applications /Library /Users/Shared /opt /usr/local 2>/dev/null
s LIBRARY_FOLDERS; du -sh ~/Library/* 2>/dev/null | sort -rh | head -15
s APP_SUPPORT; du -sh ~/Library/Application\ Support/* 2>/dev/null | sort -rh | head -15
s CACHES; du -sh ~/Library/Caches ~/Library/Developer ~/Library/Application\ Support/MobileSync ~/.Trash ~/.npm ~/.cache ~/Library/Containers ~/Library/Logs 2>/dev/null
s CACHE_BREAKDOWN; du -sh ~/Library/Caches/* ~/.cache/* ~/Library/Developer/* 2>/dev/null | sort -rh | head -15
s OLD_DOWNLOADS; find ~/Downloads -maxdepth 1 -mtime +90 -exec du -sh {} + 2>/dev/null | nz | sort -rh | head -30
s INSTALLERS; find ~/Downloads ~/Desktop ~/Documents -maxdepth 2 \( -name '*.dmg' -o -name '*.pkg' -o -name '*.zip' -o -name '*.msi' -o -name '*.exe' \) -exec du -sh {} + 2>/dev/null | nz | sort -rh | head -30
s APPS_SIZE_LASTUSED
echo "size | spotlight last used | prefs last touched | app"
for a in /Applications/*.app ~/Applications/*.app; do
  id=$(defaults read "$a/Contents/Info" CFBundleIdentifier 2>/dev/null)
  pf=~/Library/Preferences/$id.plist; ct=~/Library/Containers/$id/Data/Library/Preferences/$id.plist
  pt="unknown"; for x in $ct $pf; do [[ -e $x ]] && { pt=$(stat -f %Sm -t %Y-%m-%d "$x"); break; }; done
  echo "$(du -sh "$a" 2>/dev/null | cut -f1) | $(mdls -raw -name kMDItemLastUsedDate "$a" 2>/dev/null | cut -c1-10) | $pt | $a"
done
s NETWORK_ESTABLISHED; lsof -i -P -n 2>/dev/null | grep ESTABLISHED | awk '{print $1}' | sort | uniq -c | sort -rn
s CHROME_EXTENSIONS
for m in ~/Library/Application\ Support/Google/Chrome/*/Extensions/*/*/manifest.json; do
  n=$(grep -m1 '"name"' "$m" | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
  if [[ $n == __MSG_* ]]; then
    k=${${n#__MSG_}%__}; locs=(${m:h}/_locales/en/messages.json(N) ${m:h}/_locales/en_US/messages.json(N) ${m:h}/_locales/*/messages.json(N))
    [[ -n $locs[1] ]] && n=$(grep -i -A3 "\"$k\"" "$locs[1]" | grep -m1 '"message"' | sed -E 's/.*"message"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
  fi
  echo "${m:h:h:t} | $n | profile ${${m:h:h:h:h}:t}"
done | sort -u
s PROFILES; profiles list 2>&1 | head
s TIME_MACHINE; tmutil destinationinfo 2>&1; tmutil latestbackup 2>&1 | head -2
s ICLOUD; ls ~/Library/Mobile\ Documents/com~apple~CloudDocs 2>&1 | head -20
s END
} > "$OUT" 2>&1
echo "Done: $OUT  (you can close this window)"
