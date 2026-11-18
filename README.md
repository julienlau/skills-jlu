# skills-jlu

Personal agent skills for Julien (JLU), shared across agents and devices.

Each directory in this repo is one skill: a `SKILL.md` manifest (with the
frontmatter that drives auto-discovery) plus any `scripts/`, `references/`
or other supporting files. The same `SKILL.md` format works in opencode,
Claude Code and Codex, so the repo is installable once and synced everywhere
with a single `git pull`.

## Skills

| Skill | What it does |
|---|---|
| `jlu-pptx-to-marp` | Convert PPTX to PDF and Marp Markdown slides |
| `maki-subsession` | Delegate a sub-task to a separate maki session on a chosen provider/model (maki only; install by hand into `~/.config/maki/skills/`) |

## Install on a new device

```bash
git clone git@github.com:julienlau/skills-jlu.git  # or your symlink-friendly path
cd skills-jlu
./install.sh
```

`install.sh` links (symlinks) every skill into each tool's global skills
directory. Symlinks keep this repo the single source of truth: no duplicated
files anywhere.

Default install locations, with env overrides:

| Tool | Global skills directory | Override |
|---|---|---|
| opencode | `~/.config/opencode/skills` | `OPENCODE_SKILLS_DIR` |
| Claude Code | `~/.claude/skills` | `CLAUDE_SKILLS_DIR` |
| Codex | `~/.codex/skills` | `CODEX_HOME` (skills go in `$CODEX_HOME/skills`) |

## Update / sync across devices

Because the installs are symlinks into this repo:

```bash
git -C ~/src/skills-jlu pull     # or wherever you cloned it
```

That single pull updates opencode, Claude Code and Codex on this device at
once (they rescan skills each session). Do the same `git pull` on every other
device that ran `./install.sh`. Deleting a skill from the repo works the same
way: after `git pull`, `install.sh` prunes the now-stale links.

## Useful variations

```bash
./install.sh --tools=codex              # only link for Codex
./install.sh --copy                     # copy instead of symlink (unusual filesystems)
./install.sh --unlink                   # remove the links/copies (skills stay in the repo)
./install.sh --force                    # overwrite anything that is in the way
./install.sh --help                     # full usage
```
