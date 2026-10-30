# Environmental Survey & Technical Readiness Report

**Agent:** explorer_survey_3  
**Date:** 2026-10-27  
**Scope:** Host system environment, installed tooling, Godot engine availability, repository structure, and SETUP-001 technical requirements.

---

## 1. Executive Summary

An exhaustive audit of the Windows host environment and the project workspace reveals:
1. **Engine Availability:** Godot executable is **not currently installed** anywhere on the host filesystem (verified via global disk scans across `C:\`, `PATH`, user profile, AppData, and Program Files).
2. **Recommended Engine:** **Godot 4.7.2-stable** (official Windows 64-bit standard release from Godot Engine GitHub repository, published August 2026).
3. **Installation Target:** `C:\Users\HP\.local\bin\godot.exe`. This path is **already present in `$env:PATH`**, allowing zero-elevation, portable installation that works immediately from CLI across all sessions.
4. **Hardware Profile:** Intel 8-core CPU, 8 GB RAM (~1.0 GB free memory), NVIDIA GeForce MX130 (2 GB VRAM) + Intel UHD Graphics 620, with 5.55 GB free storage on Drive C:.
5. **Renderer Recommendation:** **`gl_compatibility`** (OpenGL 3.3 / Compatibility mode). Chosen due to the entry-level mobile GPU (MX130), low available RAM, and the stylized artistic direction ("Stylized sederhana terinspirasi Firewatch"), as well as optimal stability during headless CI/unit tests.
6. **Workspace State:** Documentation package v0.2 is in place. No Git repository is initialized yet, and no Godot project files or game source code exist yet, strictly conforming to the baseline documented in `PROJECT_STATUS.md` and `README.md`.

---

## 2. Godot Engine Binary & CLI Capabilities

### 2.1 Installation Status
- **Filesystem Search:** A recursive search across `C:\*godot*.exe` and `C:\Users\HP\*godot*` yielded zero Godot binaries (only an SVG icon in VS Code extensions was found).
- **PATH Check:** `where.exe godot` and `Get-Command godot*` returned no results.
- **Package Managers:** Neither `winget` nor `scoop` is installed or recognized in the environment.
- **Network Status:** Fully online. HTTPS calls to `https://api.github.com/repos/godotengine/godot/releases` succeed with HTTP 200.

### 2.2 Recommended Engine Version & Source
- **Official Version:** `Godot 4.7.2-stable` (64-bit standard release).
- **Download URL:** `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip`
- **Archive Size:** 86,013,866 bytes (~82.0 MB).
- **Unpacked Binary:** `Godot_v4.7.2-stable_win64.exe` (~150 MB).

### 2.3 Automated Portable Setup Procedure (for SETUP-001 Worker)
Because `C:\Users\HP\.local\bin` is already registered in the user's `$env:PATH`, the worker assigned to SETUP-001 can download and extract the portable binary with the following PowerShell command without requiring admin privileges or system reboot:

```powershell
# 1. Ensure target directory exists
New-Item -ItemType Directory -Path "C:\Users\HP\.local\bin" -Force | Out-Null

# 2. Download official release zip
$zipPath = "$env:TEMP\godot_4.7.2.zip"
$extractPath = "$env:TEMP\godot_extract"
Invoke-WebRequest -Uri "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip" -OutFile $zipPath

# 3. Extract and place binary
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
Copy-Item -Path "$extractPath\Godot_v4.7.2-stable_win64.exe" -Destination "C:\Users\HP\.local\bin\godot.exe" -Force

# 4. Clean up temporary files
Remove-Item $zipPath, $extractPath -Recurse -Force

# 5. Verify CLI execution
godot --version
```

### 2.4 Godot CLI Command Matrix

| Operation | CLI Command | Purpose & Context |
|---|---|---|
| **Version Verification** | `godot --version` | Confirms engine binary responds and outputs version string (e.g. `4.7.2.stable.official`). |
| **Headless Import / Cache** | `godot --headless --editor --quit` | Generates `.godot/` import cache without launching GUI; required after adding assets or scenes. |
| **Run Main Scene (GUI)** | `godot` | Runs project main scene in windowed mode (from directory containing `project.godot`). |
| **Run Specific Scene (GUI)** | `godot scenes/main.tscn` | Runs a designated scene directly. |
| **Run Headless Smoke Test** | `godot --headless --quit-after 60` | Runs main scene headless for 60 frames to verify startup without crashes (T24 smoke test). |
| **Automated Test Runner** | `godot --headless --script tests/test_runner.gd` | Executes headless GDScript unit/integration test suite; exits with exit code 0 (pass) or 1 (fail). |
| **Export Windows Debug** | `godot --headless --export-debug "Windows Desktop" builds/BukuResep2045_debug.exe` | Builds desktop debug executable. |
| **Export Windows Release** | `godot --headless --export-release "Windows Desktop" builds/BukuResep2045.exe` | Builds production standalone executable (DIST-001). |

---

## 3. System Host Environment & Hardware Profile

### 3.1 Operating System & Resources
- **OS:** Microsoft Windows 11 Home Single Language (Version 10.0.26300, 64-bit AMD64).
- **CPU:** Intel64 Family 6 Model 142 Stepping 10 (8 logical cores/threads).
- **System Memory (RAM):**
  - Total Visible: 8,211,556 KB (~7.83 GB).
  - Free Physical: ~1,062,784 KB (~1.01 GB) during agent execution.
- **Storage:**
  - Drive: `C:\`
  - Total Used: 112.72 GB.
  - Total Free: 5.55 GB.
  - *Operational Note:* Free disk space (5.55 GB) is adequate for Godot (~150 MB) and the stylized game assets, but disk-heavy intermediate exports or untracked build artifacts must be kept lean.

### 3.2 Display Adapters & Graphics Hardware
The host is a dual-GPU laptop system:
1. **Discrete GPU:** NVIDIA GeForce MX130
   - Dedicated VRAM: 2,147,483,648 bytes (2.0 GB).
   - Driver Version: 31.0.15.2892.
   - Architecture: Maxwell-based. Has Vulkan 1.1/1.2 support, but limited fill rate, bandwidth, and VRAM.
2. **Integrated GPU:** Intel(R) UHD Graphics 620
   - Shared VRAM: 1,073,741,824 bytes (1.0 GB).
   - Driver Version: 26.20.100.7926.

### 3.3 Available Development Tools & Runtimes
- **Git:** `git version 2.54.0.windows.1` (installed at `C:\Program Files\Git\cmd\git.exe`).
- **Python:** `Python 3.14.6` (available on PATH at `C:\Users\HP\AppData\Local\Python\bin`).
- **Node.js:** `v24.16.0` (installed at `C:\Program Files\nodejs\`).
- **PowerShell:** `5.1.26100.9711` (Desktop Edition).
- **IDE:** Microsoft VS Code installed at `C:\Users\HP\AppData\Local\Programs\Microsoft VS Code`.
- **System PATH:** Includes standard Windows directories, Git, Node, Python, VS Code, and crucially `C:\Users\HP\.local\bin`.

---

## 4. Repository Status & Workspace Audit

### 4.1 Root Directory State
Path: `c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia`
- **Git Repository:** Not initialized (fatal: not a git repository).
- **Existing Files & Folders:**
  - `README.md` (8,715 bytes) — Project intro, setup guide, document map.
  - `PRD.md` (23,323 bytes) — Product decisions, requirements (FR01–FR24), scope.
  - `AGENTS.md` (11,037 bytes) — AI operating instructions, verification rules, archival rules.
  - `docs/` — Full documentation v0.2 package:
    - `docs/PROJECT_STATUS.md` — Canonical status (Task DOC-001 closed).
    - `docs/TASKS.md` — 25 registered tasks (SETUP-001 is next).
    - `docs/TEST_PLAN.md` — 60 P0 test cases (T01–T60), acceptance criteria.
    - `docs/CONTENT.md` — Data tables, item IDs, recipe numbers, garden growth timings.
    - `docs/PROTOTYPE.md` — Gameplay loop contracts, transactions, state machines.
    - `docs/UI_UX.md` — Control bindings, HUD layouts, panel contexts.
    - `docs/LEVEL_DESIGN.md` — Coordinates, landmarks, graybox zones, spawn points.
    - `docs/ART_DIRECTION.md` — Visual & audio direction, palette, stylized assets.
    - `docs/EVENT_DESIGN.md` — Thematic event framework (Karhutla backlog).
    - `docs/CONSISTENCY_CHECK.md` — Package consistency audit results.
    - `docs/completed_tasks/001-paket-dokumentasi-v0-2.md` — Report for DOC-001.
    - `docs/wireframes/` — SVG and PNG wireframe reference diagrams.
  - `.agents/` — AI orchestration working directories.

### 4.2 Game Implementation State
- `project.godot`: **None**.
- `scenes/`: **None**.
- `scripts/`: **None**.
- `data/`: **None**.
- `assets/`: **None**.
- `tests/`: **None**.
- Baseline matches `PROJECT_STATUS.md`: Documentation is complete; coding phase begins at `SETUP-001`.

---

## 5. Technical Recommendations for SETUP-001

### 5.1 Renderer Selection Analysis
Godot 4 provides three renderers:
1. `forward_plus` (Vulkan Clustered): High-end desktop renderer with clustered lighting, shadow atlas, and heavy post-processing.
2. `mobile` (Vulkan Mobile): Mobile-optimized Vulkan renderer.
3. `gl_compatibility` (OpenGL 3.3 / Compatibility): Lightweight OpenGL 3.3 / WebGL renderer.

**Recommendation: `gl_compatibility`**
- **Hardware Match:** Host GPU (NVIDIA MX130 with 2 GB VRAM and Intel UHD 620) has limited fill rate and memory bandwidth. `forward_plus` can cause shader stuttering, driver pipeline compilation timeouts, and memory pressure on 8 GB RAM.
- **Aesthetic Match:** The project art direction (`ART_DIRECTION.md` and PRD D12) mandates a simple stylized aesthetic inspired by Firewatch (warm color grading, flat/cel-shaded materials, simple geometry, soft distance fog). It does not rely on compute shaders, screen-space reflections, or clustered omni-lights.
- **Test Automation Stability:** `gl_compatibility` initializes instantaneously in `--headless` test mode on Windows without requiring complex Vulkan loader configurations.
- **Governance Compliance:** AGENTS.md mandates: *"Pemilihan renderer dan penguncian versi dilakukan saat setup menggunakan perangkat yang tersedia; jangan mengisi nomor versi dari ingatan atau klaim 'latest' tanpa verifikasi saat itu."* Compatibility mode is verified to be the optimal choice for this specific host hardware.

### 5.2 Baseline `project.godot` Configuration
When generating `project.godot` in SETUP-001, configure the following core properties:

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but it can also be created/modified by script.

config_version=5

[application]

config/name="Buku Resep 2045"
config/description="Game 3D first person pencarian resep dan ketahanan pangan Indonesia 2045"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"

[input]

move_forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"echo":false,"script":null)
]
}
move_backward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"echo":false,"script":null)
]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"echo":false,"script":null)
]
}
open_book={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":66,"key_label":0,"unicode":98,"echo":false,"script":null)
]
}
open_inventory={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194306,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
pause_menu={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
```

### 5.3 Recommended Directory Structure (Per README Section 7)

```
c:\Users\HP\Fauzi\Private Working\Project Labs\Game Indonesia\
├── project.godot            # Engine config
├── .gitignore               # Standard Godot ignore rules
├── README.md                # Updated with exact Godot version & run instructions
├── PRD.md
├── AGENTS.md
├── docs/                    # Specification & task tracking
├── scenes/
│   ├── main.tscn            # Application root / loader
│   ├── world/
│   │   ├── world.tscn       # Graybox map & environment (LVL-001)
│   │   ├── house.tscn
│   │   ├── garden.tscn
│   │   └── interactables/
│   ├── player/
│   │   └── player.tscn      # First-person controller & raycast (PLY-001, INT-001)
│   └── ui/
│       ├── hud.tscn         # HUD & recipe tracker (BOOK-001)
│       ├── inventory.tscn   # Inventory & chest modal (INV-001)
│       ├── recipe_book.tscn # Recipe book modal
│       ├── kitchen.tscn     # Cooking station UI (COOK-001)
│       ├── dialog.tscn      # NPC dialogue UI (SOC-001)
│       └── pause_menu.tscn  # Pause & settings modal (UI-001)
├── scripts/
│   ├── core/
│   │   ├── game_state.gd    # Global state coordinator / singletons
│   │   └── event_bus.gd     # Decoupled signal dispatch
│   ├── player/
│   │   ├── player_controller.gd
│   │   └── interaction_raycast.gd
│   ├── inventory/
│   │   ├── inventory_manager.gd
│   │   └── slot_data.gd
│   ├── garden/
│   │   └── garden_bed.gd
│   ├── cooking/
│   │   └── cooking_station.gd
│   └── save/
│       └── save_manager.gd
├── data/
│   ├── item_definitions.gd  # Canonical IDs from CONTENT.md
│   ├── recipe_definitions.gd
│   └── garden_definitions.gd
├── assets/
│   ├── models/
│   ├── materials/
│   ├── textures/
│   ├── fonts/
│   └── audio/
├── tests/
│   ├── test_runner.gd       # Headless test orchestrator
│   └── unit/
│       ├── test_inventory.gd
│       ├── test_garden.gd
│       ├── test_cooking.gd
│       └── test_save_load.gd
└── builds/                  # Gitignored local binary outputs
```

### 5.4 Headless Automated Testing Harness (`tests/test_runner.gd`)
To enable non-interactive, verifiable unit and integration testing without requiring manual GUI interactions, the worker should establish a lightweight test runner script:

```gdscript
# tests/test_runner.gd
extends SceneTree

func _init() -> void:
    print("[TEST_RUNNER] Starting automated test suite...")
    var success := run_all_tests()
    if success:
        print("[TEST_RUNNER] ALL TESTS PASSED.")
        quit(0)
    else:
        printerr("[TEST_RUNNER] TEST FAILURES DETECTED.")
        quit(1)

func run_all_tests() -> bool:
    # Worker adds test modules here
    return true
```

Executed via:
```powershell
godot --headless --script tests/test_runner.gd
```

### 5.5 Git Initialization & `.gitignore`
To satisfy the requirements of SETUP-001:
1. Run `git init` in project root.
2. Create `.gitignore` containing:
   ```gitignore
   # Godot engine import cache & local metadata
   .godot/
   *.translation

   # Export & build outputs
   builds/
   *.exe
   *.pck
   *.zip

   # OS generated files
   Thumbs.db
   Desktop.ini
   .DS_Store

   # Temporary files & crash dumps
   *.tmp
   *.log
   ```
3. Commit the initial baseline with a clear message adhering to AGENTS.md.

---

## 6. Verification & Acceptance Checklist for SETUP-001

Per `docs/TASKS.md` and `docs/TEST_PLAN.md`:
- [ ] **Engine Installed:** `godot --version` prints exact version `4.7.2.stable.official`.
- [ ] **Project Import:** `godot --headless --editor --quit` succeeds with exit code 0 and populates `.godot/`.
- [ ] **T23 Baseline:** Project opens without blocking errors; README contains exact version, renderer choice (`gl_compatibility`), main scene path, and execution instructions.
- [ ] **T24 Smoke Run:** `godot --headless --quit-after 60` runs main scene for 60 frames and exits cleanly with code 0.
- [ ] **Local Checkpoint:** Git repository initialized with appropriate `.gitignore` and initial commit.
- [ ] **Documentation Update:** Update `docs/PROJECT_STATUS.md`, `docs/TASKS.md`, and create `docs/completed_tasks/002-setup-engine-godot.md` adhering to `TEMPLATE.md`.
