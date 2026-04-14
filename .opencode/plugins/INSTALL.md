# Installing ccToolBox for OpenCode

## Overview

c TOOLBOX is a collection of reusable skills and plugins designed to extend the capabilities of AI coding assistants. This guide covers installation for **OpenCode.ai**.

### What's Included

| Plugin | Description |
|--------|-------------|
| `daily-briefing` | Generates a personalized daily news/tech/weather briefing as a newspaper-styled HTML page with optional TTS audio narration |
| `offline-research` | A suite of skills for deep research, architectural analysis, and refactoring planning without live internet access |

---

## Prerequisites

### Required
- [OpenCode.ai](https://opencode.ai) installed and running
- Basic familiarity with command line (for copying files)

### Optional (for TTS audio in daily-briefing)
- **Docker** — required for text-to-speech audio generation
  - macOS: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
  - Verify installation: `docker --version`

---

## Installation Steps

### Step 1: Clone the Repository

```bash
git clone git@github.com:dev32-io/ccToolBox.git
```

Or via HTTPS:

```bash
git clone https://github.com/dev32-io/ccToolBox.git
```

---

### Step 2: Install the `daily-briefing` Plugin (Optional)

The daily briefing generates a newspaper-styled HTML page with news, tech updates, weather, and optional TTS audio narration.

#### 2.1 Create Output Directory

```bash
mkdir -p ~/.config/ccToolBox/daily-briefing/output
```

This is where your generated briefings will be saved (HTML + MP3 files).

#### 2.2 Copy the Plugin Files

```bash
cp -r ccToolBox/plugins/daily-briefing/skills ~/.config/opencode/skills/
cp -r ccToolBox/plugins/daily-briefing/agents ~/.config/opencode/agents/
cp ccToolBox/plugins/daily-briefing/scripts/tts.sh ~/.config/ccToolBox/daily-briefing/
```

#### 2.3 Set Execute Permission on TTS Script

```bash
chmod +x ~/.config/ccToolBox/daily-briefing/tts.sh
```

---

### Step 3: Install the `offline-research` Plugin (Optional)

The offline research suite provides skills for deep analysis without live internet access.

#### 3.1 Copy Skills to OpenCode Config

```bash
cp -r ccToolBox/plugins/offline-research/skills/* ~/.config/opencode/skills/
```

This installs three skills:
- `research-probe` — Deep research on technical topics using local knowledge base
- `arch-forge` — Architectural analysis and design exploration
- `refactor-probe` — Refactoring planning with safety scoring

---

### Step 4: Verify Installation

Restart OpenCode (or reload your session), then use the native `skill` tool:

```
use skill tool to list skills
```

You should see entries like:
- `daily-briefing/daily-briefing`
- `offline-research/research-probe`
- `offline-research/arch-forge`
- `offline-research/refactor-probe`

---

## Usage Examples

### Daily Briefing

Invoke with:
```
/daily-briefing
```

Or say: "get my daily briefing"

**First run:** Default settings are created at `~/.config/ccToolBox/daily-briefing/settings.md`. Edit this file to customize voice, location, and content sources.

### Offline Research Skills

Invoke with:
```
/research-probe <topic>
/arch-forge <system-description>
/refactor-probe <code-context>
```

---

## Troubleshooting

### TTS Audio Not Working

**Symptom:** Briefing HTML loads but no audio plays.

**Diagnosis:**
```bash
# Check if Docker is running
docker ps

# Test tts.sh manually
~/.config/ccToolBox/daily-briefing/tts.sh <test-text-file> /tmp/test.mp3
```

**Solutions:**
1. Start Docker Desktop if not running
2. Verify `tts.sh` is executable: `ls -la ~/.config/ccToolBox/daily-briefing/tts.sh`
3. Check that the container image pulls successfully (first run may take time)

### Skills Not Discovered

**Symptom:** Skill tool doesn't list ccToolBox skills.

**Solutions:**
1. Verify files were copied to correct locations:
   ```bash
   ls ~/.config/opencode/skills/
   ```
2. Restart OpenCode completely
3. Check that `SKILL.md` files have valid YAML frontmatter

### Settings File Issues

**Symptom:** Error about malformed settings on first run.

**Solution:** Delete the corrupted settings and let it regenerate:
```bash
rm ~/.config/ccToolBox/daily-briefing/settings.md
# Then re-run /daily-briefing
```

---

## Updating

### Update Skills

```bash
cd ccToolBox
git pull

# Re-copy updated files
cp -r plugins/daily-briefing/skills/* ~/.config/opencode/skills/
cp -r plugins/offline-research/skills/* ~/.config/opencode/skills/
```

### Update Scripts

```bash
cp ccToolBox/plugins/daily-briefing/scripts/tts.sh ~/.config/ccToolBox/daily-briefing/
chmod +x ~/.config/ccToolBox/daily-briefing/tts.sh
```

---

## Architecture Notes

### Why This Install Method?

Unlike pure-text skill collections (e.g., Superpowers), ccToolBox includes **asset dependencies** like `tts.sh` that require:
- Execute permissions (`chmod +x`)
- Known file paths accessible from skills
- Docker runtime for TTS generation

The manual copy method ensures these requirements are met without complex plugin infrastructure.

### File Locations Summary

| Item | Location |
|------|----------|
| Skills | `~/.config/opencode/skills/` |
| Agents | `~/.config/opencode/agents/` |
| TTS Script | `~/.config/ccToolBox/daily-briefing/tts.sh` |
| Briefing Output | `~/.config/ccToolBox/daily-briefing/output/` |
| Settings | `~/.config/ccToolBox/daily-briefing/settings.md` |

---

## Getting Help

- **Issues:** https://github.com/dev32-io/ccToolBox/issues
- **Documentation:** See each plugin's `README.md`
