---
name: "downloads-organizer"
description: "Smartly organize a Mac Downloads folder: sort by meaning, rename, catch duplicates and junk, archive old files, color tag and icon each folder, preview first. Use when the user says organize or clean my downloads."
---

# Downloads Organizer

Goal: keep ~/Downloads a clean, meaningful library they can tell apart at a glance. Sort by what a file IS (read its contents), not just its extension. Never delete anything. Always show a preview and wait for approval before moving or renaming.

## 0. Access

- Request folder access to `~/Downloads` once with device_request_folder_access (reason: "To read and organize your Downloads folder"). If already connected, skip.
- Do all work on their computer with device_bash under `$HOME/mnt/Downloads`. Only stage a file to the cloud when you must look at an image or a scanned PDF page yourself (batch images into one contact sheet).
- Tools on their side: pdftotext, python3, unzip, sha256sum. Device xattrs pass straight through to macOS (limit 64 KB per xattr).

## 1. Inventory (loose items only)

On the first run, create the structure below. After that, process loose top level items plus anything new dropped in the top of each main folder. Skip:

- Anything modified in the last 10 minutes, plus `.crdownload`, `.download`, `.part` files still growing
- Folders that look like projects (`.git`, `package.json`, `.xcodeproj`, `.twb Files`, textbook data sets); move them whole, never dig inside
- `.app` bundles (move whole to Software)
- `⚙️ _Organizer` and hidden `Icon\r` files

For each file collect: name, size, extension, mtime, sha256 (under 500 MB), and a content peek:

- PDF: first ~1500 chars via `pdftotext -l 2`. If no text (scanned), stage and Read page 1.
- DOCX/XLSX/PPTX/CSV/TXT/MD/ICS: first ~1500 chars of text, sheet names, or SUMMARY/DTSTART via python
- Images: name pattern first; stage ambiguous ones and view them together on one contact sheet
- Zips/twbx: list contents without extracting

## 2. Classify by meaning

Use the content peek plus filename to pick a home. Existing layout:

| Folder | Finder tag | Icon key / color | Notes |
|---|---|---|---|
| 📚 School/<semester>/<course> | Blue | School #2F6FEB | one folder per semester, one per course |
| 💼 Career | Purple | Career #8B5CF6 | resumes, cover letters, offers, applications |
| 🧤 Work/<employer> | Orange | Work #F97316 | job and internship deliverables |
| 💵 Money | Green | Money #16A34A | receipts, taxes, loans, statements |
| 🔒 Personal/Documents | Gray | Personal #475569 | IDs, insurance, transcripts, medical, lease; never stage unless needed |
| 🎮 Hobbies/<hobby> | Yellow | Hobbies #EAB308 | one subfolder per hobby |
| 🛠️ Projects/<name> | Gray | Projects #0EA5E9 | one subfolder per project |
| 🖼️ Media/Photos, Wallpapers, Images | Yellow | Media #EC4899 |  |
| 💿 Software | Gray | Software #64748B | installers still needed, apps |
| 🗄️ Archive/<YYYY>/<MM> | Gray | Archive #A8A29E |  |
| ❓ _Sort Later | Orange | (make one, #FB923C) | only when needed |
| 🗑️ _Review to Delete/Duplicates, Used Installers, Office Temp Files, Empty Folders, Empty Files | Red | Review_to_Delete #DC2626 |  |
| ⚙️ _Organizer/logs, icons, icons/rsrc | none | none |  |

Rules:

- Course work goes in the current semester's course folder when the content names the course, professor, assignment, or topic (keep a short topic to course map here, for example Solver = Decision Analysis). New semester: create `📚 School/<Season YYYY>/`.
- Project assets (branding, thumbnails, scripts, app icons, web files) go to their project folder.
- New top level categories only if 5+ files need one; otherwise use the closest folder.
- Unsure items go to `❓ _Sort Later/` with a one line reason. Never guess wildly.

## 3. Rename

Format: `YYYY-MM-DD Topic Description.ext` for files with random or junk names.

- Date from content if clear, else mtime. Description is 2 to 6 plain words from the content.
- Leave alone: clear names, class submission names (`Exam2_Lastname_Firstname.twbx`), installers, project files, resumes.
- Fix junk: `(1)`, `copy`, `.pdf.pdf`, `.pjeg`, `Document3`, hash names, `_tmp_` prefixes. On collision append ` 2`, ` 3`.

## 4. Duplicates, junk, archive

- Duplicates: same sha256 anywhere in Downloads. Keep the copy in the most meaningful folder (or the one inside a textbook/template bundle); move the rest to `🗑️ _Review to Delete/Duplicates/`. Intentional backups (app backups) and Tableau packaged data stay.
- Office lock files `~$*` go to `Office Temp Files`.
- Used installers (`.dmg`, `.pkg`) go to `Used Installers` when the app looks installed; say so in the preview so they can confirm.
- Empty folders left after moves go to `Empty Folders` (no delete permission needed).
- Archive: loose items untouched 60+ days go to `🗄️ Archive/<YYYY>/<MM>/`. Career and Personal files never archive.

## 5. Preview (required)

Build the plan as a JSON list of `(src, dst, reason, group)` in `$HOME/org/plan.json` on their machine and check every source exists. Then send a preview with SendUserMessage: one table by destination folder with counts and notable renames, a separate Review to Delete section with sizes, and any heads up (renaming folders breaks Recent Files links in Office and Tableau). Ask with AskUserQuestion: Run it / Tweak first / Cancel. Apply tweaks, re show only changed rows, ask again.

## 6. Execute

- Write the manifest first: `⚙️ _Organizer/logs/<YYYY-MM-DD_HHMM>.csv` with `old_path,new_path,action`.
- Move in plan order with `mv -n` only (never plain mv, never rm), skipping any src missing or dst existing. Verify each move and report skips.

## 7. Style the folders (no GUI needed)

Only style folders that are new or missing their style.

**Color tags:** python on the device: `os.setxattr(path, 'com.apple.metadata:_kMDItemUserTags', plistlib.dumps(['Blue\n4'], fmt=plistlib.FMT_BINARY))`. Codes: Gray 1, Green 2, Purple 3, Blue 4, Yellow 5, Red 6, Orange 7. Tag the main folder and its direct subfolders.

**Custom icons:** resource forks live in `⚙️ _Organizer/icons/rsrc/<Key>.rsrc` (PNGs beside them). Apply with python on the device:

1. Create an empty file `Icon\r` inside the folder.
2. Set its `com.apple.ResourceFork` xattr to the .rsrc bytes.
3. Set its `com.apple.FinderInfo` to 32 bytes: `icon`, `MACS`, then flags `0x4000` (invisible) at offset 8.
4. Read the folder's `com.apple.FinderInfo` (or 32 zero bytes), OR `0x0400` (has custom icon) into the flags at offset 8, write it back, then touch the folder.

New icon needed (new category or subfolder): generate a 1024 PNG with Pillow in the cloud (rounded macOS folder in the category color, white circle badge with the Noto Color Emoji centered), show them a contact sheet first, then build an icns of PNG entries (icp4 16, icp5 32, ic11 32, ic12 64, ic07 128, ic13 256, ic08 256, ic14 512, ic09 512; quantize to 256 colors) wrapped in a resource fork with one `icns` resource id -16455. Keep the .rsrc under 64 KB. Commit PNG and .rsrc to the icons folders.

Do NOT use Finder's Go to Folder or Get Info through background computer use: Finder ignores background return/escape, which leaves a dialog stuck open.

**Finder view (optional, ask once):** offer icon view sorted by Kind so the colored folders sit at the top.

## 8. Report

Short summary: files sorted, renamed, duplicates found, archived, folders styled, items in `🗑️ _Review to Delete` with total size, anything skipped. End with one next step.

## Undo

If they says undo, read the latest manifest and move each `new_path` back to `old_path` with `mv -n`, last move first, then report. Styling stays unless they asks to remove it (clear the 0x0400 flag and move `Icon\r` to Review to Delete).

## Writing style

Casual, short, scannable. No em dashes or en dashes in anything written to them.