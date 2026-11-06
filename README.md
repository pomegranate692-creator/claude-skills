# Claude Skills

Reusable workflows I built so Claude handles my repeat tasks the same way every time. A skill is a saved playbook: steps, rules and safety checks that Claude follows whenever a matching request comes in.

Built by [Romaan Malik](mailto:malikromaan7878@gmail.com), Operations Management and Information Systems at Northern Illinois University.

## The skills

| Skill | What it does | Say this |
|---|---|---|
| [Mac Checkup](mac-checkup/) | Checks a Mac across six areas (health, startup items, storage, unused apps, intrusions, backups), puts the findings on a dashboard, and runs only the fixes you approve. | "run my mac checkup", then "run my approved fixes" |
| [Downloads Organizer](downloads-organizer/) | Sorts a messy Downloads folder by what each file actually is, renames junk names, catches duplicates, archives old files, and color tags each folder. Shows a full preview first. | "organize my downloads" |

## How they stay safe

Both skills follow the same rules:

1. **Look first, change nothing.** Scans and inventories are read only.
2. **Preview and approve.** Nothing moves, renames or gets removed until you say yes.
3. **Never permanently delete.** Removals go to the Trash or a Review to Delete folder, and you empty it yourself.
4. **Everything is logged.** Downloads Organizer writes a manifest of every move, so "undo" puts it all back.

## Install

**Claude app (Cowork or claude.ai):** zip a skill's folder, then go to Settings, Capabilities, Skills and upload the zip.

**Claude Code:** copy a skill's folder into `~/.claude/skills/`.

Both skills expect Claude to reach your Mac through the Claude desktop app with folder access. Mac Checkup also uses a dashboard artifact; it creates one on the first run.

## Mac Checkup files

- `SKILL.md`: the playbook Claude follows.
- `collect.command`: the read only collector. Double click it on your Mac, or let the optional LaunchAgent run it. It lists and measures and changes nothing.

## Results from my own Mac

One checkup and one round of approved fixes took my Mac from 9.5 GB free to 32 GB free.

## License

MIT. Use them, change them, make them yours.
