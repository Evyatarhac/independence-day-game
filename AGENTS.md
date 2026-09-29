# Base44 Dev Environment — Independence Day Beat 'Em Up (Godot 4.6)

## What this is

A 2D arcade beat 'em up built with **Godot 4.6** (GDScript). All art is procedural
(drawn in code) or from local image assets. No external services or credentials
are required — the `AdsManager` simulates ads with local JPGs, not real AdMob.

## How it runs in the preview

Godot games don't have a live-reload dev server. The workflow is **export → serve**:

1. The GDScript source is exported to HTML5 (WebAssembly) using the Godot editor.
2. The exported files (`export/web/`) are served by **nginx** on port 3000.

`docker-compose.base44.yml` defines two services:

- **`web`** (default, always runs) — `nginx:alpine` serving `export/web/` on port 3000.
- **`exporter`** (profile `build`, opt-in) — builds a Docker image with Godot 4.7.2 +
  web export templates, then re-exports the project. Run it after editing GDScript:
  ```bash
  docker compose -f docker-compose.base44.yml run --rm exporter
  ```
  Then call `reload_preview` so the browser picks up the new build.

### Fast re-export (host Godot binary)

If the Godot 4.7.2 editor binary is already on the host (e.g. `/tmp/Godot_v4.7.2-stable_linux.x86_64`),
re-exporting is much faster than the Docker exporter:
```bash
cd /app
cp .base44/export_presets.cfg export_presets.cfg
/tmp/Godot_v4.7.2-stable_linux.x86_64 --headless --import
mkdir -p export/web
/tmp/Godot_v4.7.2-stable_linux.x86_64 --headless --export-release "Web"
```

## Key files

| File | Purpose |
|------|---------|
| `docker-compose.base44.yml` | Compose: nginx web server + optional Godot exporter |
| `Dockerfile.godot` | Image with Godot 4.7.2 editor + web export templates |
| `nginx.godot.conf` | nginx config with correct MIME types for .wasm/.pck |
| `.base44/export_presets.cfg` | Web export preset (copied to `export_presets.cfg` at export time; the latter is gitignored) |
| `export/web/` | HTML5 export output (gitignored, regenerated on export) |

## Project structure

- `project.godot` — Godot project config (main scene: `scenes/MainMenu.tscn`)
- `scenes/` — MainMenu, CharacterSelect, Game, GameOver, NameEntry, IntroSequence
- `scripts/` — Game logic, Player, Enemy, HUD, TouchControls, AdsManager, GameData
- `assets/` — Backgrounds, flag graphics, audio, screenshots
- `make_intro.py` — Python script to generate intro cinematic (not needed for the game)

## Verifying it works

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/index.html   # 200
curl -s -I http://localhost:3000/index.wasm | grep -i content-type        # application/wasm
```
