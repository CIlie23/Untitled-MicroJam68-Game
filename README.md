# Untitled-MicroJam68-Game
hi

# Project Structure Guide

This project follows a **feature-oriented (contextual)** organization. Related scenes, scripts, and entity-specific assets are kept together rather than split into disparate top-level folders.

---

## Directory Overview

```text
res://
├── assets/                  # Shared raw assets
│   ├── audio/               # Background music and shared sound effects
│   ├── fonts/               # Typography files (.ttf, .otf, FontFile resources)
│   ├── shaders/             # Reusable visual and canvas shaders (.gdshader)
│   └── textures/            # Shared textures, environment sprites, icons
│
├── data/                    # Concrete custom Resource instances (.tres files)
│   ├── items/               # Equipment, consumable, and inventory data
│   └── stats/               # Unit stats, balancing numbers, attribute configs
│
└── src/                     # Game logic, scenes, and mechanics
    ├── autoload/            # Global singletons (Event bus, persistent state)
    ├── common/              # Shared base systems and utilities
    │   ├── components/      # Reusable sub-nodes (Hitbox, Hurtbox, Health)
    │   ├── resources/       # Custom Resource definitions (class_name ... extends Resource)
    │   └── utils/           # Pure functional helpers, math libs, constants
    ├── entities/            # In-game dynamic actors (player, NPCs, enemies)
    ├── levels/              # Playable maps, rooms, arenas, and level logic
    └── ui/                  # User interface scenes and menus
```

---

## What Goes Where?

### 1. `assets/` (Shared Media)
* **Rule:** Store only media used across multiple entities or systems.
* **Examples:** Default UI fonts, ambient music, environmental tilesets, footstep audio, global particle textures.
* **Note:** If an asset belongs strictly to one actor (e.g., a boss's bespoke sprite sheet), keep it inside that actor's folder in `src/entities/`.

### 2. `data/` (Concrete Resources)
* Stores `.tres` (Text Resource) data instances created in the inspector.
* Keeps tuning, balancing numbers, and database-style entries out of code and separated from scene graphs.

### 3. `src/autoload/` (Singletons)
* **Keep minimal.** Use primarily for:
  * **Event Bus** (`events.gd`) for broadcast signals between distant nodes.
  * **Global State** (`game_state.gd`) for session flags, settings, or scene transitions.
* Avoid dumping gameplay logic or actor references into autoloads.

### 4. `src/common/` (Shared Building Blocks)
* **`components/`**: Modular logic nodes attached to entities (e.g., `HealthComponent.tscn`, `Hitbox.tscn`, `InteractionArea.tscn`).
* **`resources/`**: Script definitions for resources (e.g., `item_data.gd`, `enemy_stats.gd`).
* **`utils/`**: Stateless helper classes with static functions (e.g., vector math, save-file serialization).

### 5. `src/entities/` (Actors)
* Co-locate an entity's `.tscn`, `.gd`, local assets, and sub-systems in the same folder:
  ```text
  entities/player/
  ├── player.tscn
  ├── player.gd
  ├── player_sprite.png
  └── states/
      ├── idle_state.gd
      └── move_state.gd
  ```

### 6. `src/levels/` (Scenes & Environments)
* Playable spaces, scene composition, and level-specific scripting (e.g., `level_01.tscn`, `arena_boss.tscn`).

### 7. `src/ui/` (Interface)
* **`menus/`**: Fullscreen flows like `main_menu.tscn`, `options_menu.tscn`, `game_over.tscn`.
* **`hud/`**: In-game overlays like health bars, inventories, minimaps, and hotbars.

---

## Architecture Conventions

* **Co-location:** Always keep a scene and its primary script together in the same directory with matching names (`my_node.tscn` and `my_node.gd`).
* **Signal Up, Call Down:** A parent can call child methods directly (`$Hurtbox.take_damage()`), but children should notify parents via signals (`signal health_depleted`) to prevent tight coupling.
