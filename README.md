# 🇮🇱 Independence Day Beat 'Em Up

A retro arcade beat 'em up game set during the Israeli War of Independence (1948), built with **Godot 4.3**.

Inspired by classic arcade fighters like Streets of Rage and Final Fight — side-scrolling action with historically-styled pixel art characters.

---

## Gameplay

- Choose your fighter from four underground organizations: **Palmach, Lehi, Haganah, or Irgun**
- Battle through waves of enemies across the streets of 1948 Jerusalem
- Side-scrolling beat 'em up with touch controls for mobile
- Combo attacks, pickups, and a scrolling leaderboard (name entry)

## Characters

| Fighter | Organization | Style |
|---|---|---|
| Palmach | Pre-state IDF elite units | Rifle sling, deep olive uniform |
| Lehi | Underground resistance | Dual pistols, dark civilian clothes |
| Haganah | Jewish defense force | British khaki, bandolier |
| Irgun | National military organization | Wide-brim cap, dark olive |

## Platforms

- **Web / HTML5** — playable in browser
- **Android** — via Godot export
- **iOS** — via Godot export

## Tech Stack

- **Engine:** Godot 4.3 (GDScript)
- **Monetization:** AdMob (mobile) / AdSense (web) with rewarded video ads
- **Assets:** Procedural pixel art (drawn in code), OGV video for intro cinematic

## Project Structure

```
scenes/       — MainMenu, CharacterSelect, Game, GameOver, IntroSequence, NameEntry
scripts/      — Game logic, Player, Enemy, HUD, TouchControls, AdsManager
assets/       — Background images, flag graphics, audio/video files
```

## Running the Project

1. Install [Godot 4.3](https://godotengine.org/download/)
2. Open `project.godot`
3. Press **F5** to run

## Historical Context

The game is set during the 1948 Israeli War of Independence — the period when Israel declared statehood and fought for its survival. Characters are inspired by the real underground organizations that became the foundation of the IDF.

---

*Built for Israeli Independence Day (יום העצמאות) — a historical arcade tribute.*
