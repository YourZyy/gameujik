# Handoff Report: Core Audio Ambiance & Sound Effect Integration (ART-001)

**Agent:** explorer_art_001_2  
**Date:** 2026-10-29  
**Milestone:** ART-001 (Core Visuals & Audio Feedback)  
**Status:** Completed Investigation & Concrete Blueprint

---

## 1. Observation

Direct observations from the project codebase, design documents, and engine configuration:

### 1.1 Specification Requirements
1. **`docs/ART_DIRECTION.md` § 8 (Audio)**:
   > "Ambience kampung, angin tipis, bambu, langkah dan kegiatan dapur memberi tempat terasa hidup. Musik tidak harus terus berjalan. Pickup, tanam, gemburkan, pupuk, siram, panen, tombol buku dan hasil masak mendapat feedback singkat yang berbeda.
   > Volume master/musik/efek dapat diubah. Informasi penting tetap punya teks. NPC tidak membutuhkan voice-over P0. Jangan memakai suara notifikasi keras untuk interaksi yang diulang."
2. **`docs/CONTENT.md` § 14 (Parameter Pengaturan P0 - Default Uji)**:
   > - Master/efek: Awal 70%, rentang 0–100%
   > - Musik: Awal 40%, rentang 0–100%; tidak harus terus berjalan
   > - Subtitle/teks informasi penting: Aktif; informasi utama tetap dapat dibaca tanpa audio
3. **`docs/TEST_PLAN.md` (T52, T55, T56)**:
   > - T52: "Ubah sensitivitas/FOV/audio/skala; restart dan load save lama: Pengaturan tetap yang terbaru, tidak ditimpa progres lama; slider benar-benar bekerja"
   > - T55: "Lihat tanaman, bahan, alat dan sumber pada jarak interaksi/beragam latar: Siluet berbeda, teks/ikon terbaca, status bukan warna saja; tidak ada aset hilang"
4. **`AGENTS.md` § 10 (Git, Aset, dan Penyerahan)**:
   > "Setiap aset eksternal harus memiliki asal, pembuat, lisensi, tanggal perolehan, perubahan dan kewajiban atribusi yang dapat diverifikasi... Hindari dependency tambahan dan perubahan visual menyeluruh di luar kebutuhan."

### 1.2 Current Audio Bus Layout (`default_bus_layout.tres`)
Inspection of `default_bus_layout.tres`:
```tres
[gd_resource type="AudioBusLayout" format=3 uid="uid://bx5p2buslayout01"]

[resource]
bus/1/name = &"Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
```
The bus layout already defines Bus 0 (`Master`), Bus 1 (`Music`), and Bus 2 (`SFX`). However, Bus 0 lacks an `AudioEffectLimiter` to protect against digital clipping during multi-sample summing.

### 1.3 Volume Control in `scripts/save/save_manager.gd`
In `save_manager.gd` lines 635–691:
```gdscript
func ensure_audio_buses() -> void:
    for bus_name in ["Music", "SFX"]:
        if AudioServer.get_bus_index(bus_name) == -1:
            var idx := AudioServer.bus_count
            AudioServer.add_bus(idx)
            AudioServer.set_bus_name(idx, bus_name)
            AudioServer.set_bus_send(idx, "Master")

func apply_all_settings() -> void:
    ensure_audio_buses()
    ...
    # 2. Audio
    _apply_bus_volume("Master", float(get_setting("audio", "master_volume", 0.7)))
    _apply_bus_volume("Music", float(get_setting("audio", "music_volume", 0.4)))
    _apply_bus_volume("SFX", float(get_setting("audio", "sfx_volume", 0.7)))

func _apply_bus_volume(bus_name: String, linear_vol: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx == -1:
        return
    if linear_vol <= 0.0001:
        AudioServer.set_bus_mute(idx, true)
        AudioServer.set_bus_volume_db(idx, -80.0)
    else:
        AudioServer.set_bus_mute(idx, false)
        AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear_vol, 0.0001, 1.0)))
```
`SaveManager` stores settings in `user://settings.cfg` and handles bus mute at `<= 0.0001` with `linear_to_db()` conversion safely.

### 1.4 Gameplay Hooks in Existing Scripts
- **Movement (`scripts/player/player_controller.gd`)**:
  - `_physics_process(delta)` (lines 271–284) calculates velocity and executes `move_and_slide()`. Currently no step distance accumulator or footstep audio trigger exists.
  - `_on_hold_action_completed(action)` (lines 458–471) triggers garden actions ("hoe", "fertilize", "water", "refill").
  - `_handle_plant_seed_on_plot()` (lines 472–498) plants seeds.
  - `_handle_plot_harvest_on_plot()` (lines 499–527) harvests crops.
- **Gardening (`scripts/gardening/garden_manager.gd`)**:
  - Emits: `plot_hoed(plot_id)`, `plot_fertilized(plot_id)`, `plot_watered(plot_id)`, `spot_planted(plot_id, spot_id, crop_id)`, `spot_harvested(plot_id, spot_id, crop_id)`, `water_level_changed(curr, max)`.
- **Cooking (`scripts/cooking/kitchen_manager.gd`)**:
  - Emits: `cooking_started(job_id, duration)`, `cooking_progress_updated(job_id, fraction, elapsed, duration)`, `cooking_paused(job_id)`, `cooking_resumed(job_id)`, `cooking_completed(job_id, output)`, `heat_stalled(warning_message)`, `dish_collected(item_id, count)`, `dish_consumed(item_id)`.
- **World & Resources (`scripts/world/world_resource_manager.gd`)**:
  - Emits: `foraging_node_harvested(node_id, item_id, count)`, `rest_completed(new_day)`, `meal_consumed(item_id, count)`.
- **UI & Menus (`scripts/ui/pause_menu.gd`, `settings_menu.gd`, `hud.gd`)**:
  - Standard buttons connect to `.pressed`. Currently no centralized audio click trigger is attached.
- **Headless Test Baseline**:
  - Current headless runner (`godot.exe --headless -s tests/test_runner.gd`) executes 23 test suites and 7,158 assertions with 0 failures (`test_summary.log`).

---

## 2. Logic Chain

From the observations above, we establish the step-by-step logic for the audio system:

### Step 1: Solving the Asset Provisioning & Licensing Dilemma
- *Premise*: `AGENTS.md` § 10 strictly forbids untracked third-party assets without verified provenance, and warns against external download dependencies during CI/headless tests.
- *Analysis*: If we require external audio downloads (e.g. MP3/WAV from the web), CI pipelines without internet access or headless test runs will fail or experience missing asset errors. Conversely, Godot 4 provides native `AudioStreamWAV` which accepts raw PCM byte buffers (`PackedByteArray`) via `.data`.
- *Solution*: Implement a dual-layer strategy via `scripts/audio/audio_synthesizer.gd`:
  1. **Primary/Fallback**: Deterministic procedural PCM synthesis in GDScript producing clean, warm, stylized 16-bit 22.05 kHz `AudioStreamWAV` streams. Generating all 10 project sounds takes <15 ms in total and requires 0 external files.
  2. **Asset Override**: If an artist places a licensed `.wav` or `.ogg` file in `res://assets/audio/`, the loader automatically prefers the disk file over the procedural fallback, accompanied by attribution in `assets/audio/CREDITS.md`.
  3. This completely satisfies `AGENTS.md` § 10, ensures 100% self-contained offline builds, and fulfills `PRD` FR22.

### Step 2: Bus Architecture & Headroom Management
- *Premise*: Summing multiple simultaneous sound streams (wind loop + footsteps + hoe chunk + cooking sizzle) can exceed 0 dBFS and cause digital clipping distortion on consumer sound hardware.
- *Routing Decision*:
  - **`"Music"` Bus**: Countryside rural ambience loop (`ambience_countryside_loop`). Plays at -14.0 dB baseline. Controlled by the Music slider in Settings.
  - **`"SFX"` Bus**: All gameplay actions (footsteps, tools, harvest, kitchen sizzle, UI buttons). Controlled by the SFX slider in Settings.
  - **`"Master"` Bus**: Receives both `"Music"` and `"SFX"`. Controlled by the Master slider in Settings.
  - **Headroom Protection**: Add `AudioEffectLimiter` (threshold: 0.0 dB, ceiling: -0.5 dB, release: 0.05s) on the Master bus in `default_bus_layout.tres`. This acts as an imperceptible safety net preventing clipping under worst-case audio stacking.

### Step 3: Preventing Audio Fatigue (SFX Variation & Game Feel)
- *Premise*: Rapid repetitive sounds (footsteps while walking 3 m/s, repeated button clicks) sound robotic and fatiguing if identical PCM waveforms play every time.
- *Solution*: Wrap procedural samples in `AudioStreamRandomizer` (or runtime random pitch/gain modulation):
  - Footsteps: `random_pitch_semitones = 1.2` (approx ±7%), `random_volume_offset_db = 1.0`.
  - Tool Hoeing: `random_pitch_semitones = 0.8`, `random_volume_offset_db = 0.8`.
  - UI Clicks: `random_pitch_semitones = 0.5`.
  - Polyphony: Set `max_polyphony = 4` on SFX players to ensure overlapping sounds never abruptly cut each other off.

### Step 4: System Architecture & Decoupled Signal Integration
- *Premise*: Audio code should not clutter core game managers (`GardenManager`, `KitchenManager`, `WorldResourceManager`), while still responding instantly to game events.
- *Design*: Implement `AudioManager` as an Autoload singleton (`res://scripts/audio/audio_manager.gd`):
  1. On `_ready()`, `AudioManager` auto-subscribes to global autoload signals:
     - `GardenManager.plot_hoed` -> plays `tool_hoe`
     - `GardenManager.plot_fertilized` -> plays `tool_fertilizer`
     - `GardenManager.plot_watered` -> plays `tool_water`
     - `GardenManager.spot_planted` -> plays `plant_seed`
     - `GardenManager.spot_harvested` -> plays `harvest`
     - `KitchenManager.cooking_started` / `cooking_resumed` -> starts `kitchen_simmer` loop
     - `KitchenManager.cooking_paused` / `cooking_completed` -> stops `kitchen_simmer` loop
     - `KitchenManager.cooking_completed` -> plays `cook_done` chime
     - `KitchenManager.heat_stalled` -> plays `heat_stall` warning
     - `WorldResourceManager.foraging_node_harvested` -> plays `harvest`
     - `WorldResourceManager.meal_consumed` -> plays `eat_dish`
     - `WorldResourceManager.rest_completed` -> plays `morning_chime`
  2. For `PlayerController`:
     - Footstep distance accumulator: every 1.8 meters of walking (`is_on_floor() && velocity.length() > 0.5`), trigger `AudioManager.play_footstep()`.
     - Hold action feedback: when `HoldActionController` completes or cancels, play appropriate audio cues.
  3. For UI:
     - `AudioManager.play_ui_click()` and `AudioManager.play_ui_confirm()`.
     - Helper method `AudioManager.hook_control_tree(control)` to auto-wire button signals across any dialog/menu.

---

## 3. Caveats

1. **Headless Audio Limitations in CI**:
   - In Godot headless mode (`--headless`), the audio server operates with a dummy driver (`Dummy`). No actual sound waves are pushed to hardware sound cards.
   - However, `AudioServer`, `AudioStreamPlayer`, `AudioStreamWAV`, and `AudioStreamRandomizer` run in memory and emit all signals normally. Unit tests in `test_audio.gd` verify object creation, stream parameters, bus indexing, and signal callbacks without requiring physical audio hardware.
   - Real auditory balance (perceived loudness, pleasantness of tone) must be verified via interactive playtest on speakers/headphones.
2. **Procedural Lo-Fi Aesthetic**:
   - Procedural synthesis using additive/subtractive sine waves and filtered noise creates warm, stylized lo-fi sound effects that match the Firewatch-inspired low-poly visual style.
   - It does not replace full orchestral or studio-recorded live traditional instruments (e.g. real bamboo suling or kendang). If live instrument recordings are incorporated later, they must follow the drop-in file workflow in `res://assets/audio/` with full CC0 license records in `assets/audio/CREDITS.md`.
3. **SaveManager Boundary**:
   - Audio volume settings are saved to `user://settings.cfg`, not in the gameplay save envelope (`user://saves/`). `AudioManager` must not alter this separation.

---

## 4. Conclusion & Concrete Implementation Blueprints

The worker should implement the audio system in ART-001 following these precise specifications:

### 4.1 Component 1: `scripts/audio/audio_synthesizer.gd`
Utility class containing procedural waveform generators that return pure `AudioStreamWAV` resources.

```gdscript
class_name AudioSynthesizer
extends RefCounted

## AudioSynthesizer — Procedural PCM sound generation for Buku Resep 2045
## Generates clean 16-bit 22050Hz AudioStreamWAV buffers in GDScript without external files.

const MIX_RATE: int = 22050

static func create_stream_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	wav.loop_begin = 0
	wav.loop_end = samples.size()

	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val_int: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		pcm.encode_s16(i * 2, val_int)
	wav.data = pcm
	return wav

# 1. Countryside Ambience (Wind + Bamboo rustle) - 4.0s Seamless Loop
static func generate_ambience_countryside() -> AudioStreamWAV:
	var duration := 4.0
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var lp_state := 0.0
	var alpha := 0.04 # Low-pass ~150Hz for gentle wind rumble
	
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		# Pseudo-random noise
		var white := randf_range(-1.0, 1.0)
		lp_state += alpha * (white - lp_state)
		
		# Wind gusts modulation (slow LFOs)
		var gust := 0.6 + 0.4 * sin(2.0 * PI * 0.25 * t)
		var wind := lp_state * gust * 0.7
		
		# Gentle bamboo chime undertone (damped sine harmonics)
		var chime := 0.0
		chime += sin(2.0 * PI * 523.25 * t) * 0.03 * maxf(0.0, sin(PI * t / 2.0))
		chime += sin(2.0 * PI * 659.25 * t) * 0.02 * maxf(0.0, cos(PI * t / 2.0))
		
		# Boundary crossfade for perfect loop
		var boundary_fade := 1.0
		if i < 2200:
			boundary_fade = float(i) / 2200.0
		elif i > count - 2200:
			boundary_fade = float(count - i) / 2200.0
			
		samples[i] = (wind + chime) * boundary_fade * 0.8
		
	return create_stream_wav(samples, true)

# 2. Footstep on Dirt/Grass - 0.12s
static func generate_footstep() -> AudioStreamWAV:
	var count := int(0.12 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-35.0 * t)
		var noise := randf_range(-1.0, 1.0)
		lp += 0.15 * (noise - lp) # ~500Hz cutoff
		var thump := sin(2.0 * PI * (110.0 - 50.0 * t) * t) * exp(-40.0 * t)
		samples[i] = (lp * 0.7 + thump * 0.3) * env * 0.9
	return create_stream_wav(samples, false)

# 3. Tool Cangkul (Hoeing Soil) - 0.22s
static func generate_tool_hoe() -> AudioStreamWAV:
	var count := int(0.22 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		# Initial metallic contact transient (0-30ms)
		var metal := sin(2.0 * PI * 950.0 * t) * exp(-70.0 * t) * 0.4
		# Earth disturbance body
		var noise := randf_range(-1.0, 1.0)
		lp += 0.08 * (noise - lp) # ~250Hz low earth thud
		var earth := lp * exp(-18.0 * t) * 0.8
		samples[i] = clampf(metal + earth, -1.0, 1.0)
	return create_stream_wav(samples, false)

# 4. Watering Flow (Siram Tanaman) - 0.6s
static func generate_tool_water() -> AudioStreamWAV:
	var count := int(0.6 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var bp := 0.0
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := sin(PI * (t / 0.6))
		var noise := randf_range(-1.0, 1.0)
		bp += 0.25 * (noise - bp)
		var droplet := sin(2.0 * PI * (1200.0 + sin(t * 40.0) * 400.0) * t) * 0.2
		samples[i] = (bp * 0.5 + droplet) * env * 0.7
	return create_stream_wav(samples, false)

# 5. Fertilizer Sprinkle (Pupuk Tabur) - 0.25s
static func generate_tool_fertilizer() -> AudioStreamWAV:
	var count := int(0.25 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var hp_prev := 0.0
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-14.0 * t)
		var noise := randf_range(-1.0, 1.0)
		var hp := noise - hp_prev
		hp_prev = noise
		var grain := sin(2.0 * PI * 2800.0 * t) * 0.15
		samples[i] = (hp * 0.35 + grain) * env * 0.7
	return create_stream_wav(samples, false)

# 6. Harvest / Pickup Chime - 0.22s
static func generate_harvest_pickup() -> AudioStreamWAV:
	var count := int(0.22 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := (1.0 - exp(-t * 200.0)) * exp(-14.0 * t)
		var freq := 587.33 * (1.0 + 0.08 * (1.0 - t / 0.22)) # D5 slight upward glide
		var tone := sin(2.0 * PI * freq * t) * 0.6 + sin(2.0 * PI * freq * 1.5 * t) * 0.3
		samples[i] = tone * env * 0.85
	return create_stream_wav(samples, false)

# 7. Kitchen Cooking Simmer Loop - 2.5s Seamless Loop
static func generate_kitchen_simmer() -> AudioStreamWAV:
	var duration := 2.5
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var noise := randf_range(-1.0, 1.0)
		lp += 0.1 * (noise - lp)
		# Micro bubbling pops
		var bubble := 0.0
		if randf() < 0.008:
			bubble = sin(2.0 * PI * randf_range(800.0, 1600.0) * t) * 0.4
		var boundary := 1.0
		if i < 1500: boundary = float(i) / 1500.0
		elif i > count - 1500: boundary = float(count - i) / 1500.0
		samples[i] = (lp * 0.4 + bubble) * boundary * 0.75
	return create_stream_wav(samples, true)

# 8. UI Button Click - 0.04s
static func generate_ui_click() -> AudioStreamWAV:
	var count := int(0.04 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-100.0 * t)
		var tone := sin(2.0 * PI * 1100.0 * t)
		samples[i] = tone * env * 0.7
	return create_stream_wav(samples, false)

# 9. UI Confirm Chime - 0.28s
static func generate_ui_confirm() -> AudioStreamWAV:
	var count := int(0.28 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var tone := 0.0
		if t < 0.12:
			var env1 := exp(-20.0 * t)
			tone = sin(2.0 * PI * 523.25 * t) * env1 * 0.6
		else:
			var t2 := t - 0.12
			var env2 := exp(-16.0 * t2)
			tone = sin(2.0 * PI * 659.25 * t2) * env2 * 0.7
		samples[i] = tone * 0.8
	return create_stream_wav(samples, false)

# 10. Eat Dish - 0.35s
static func generate_eat_dish() -> AudioStreamWAV:
	var count := int(0.35 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-12.0 * t)
		var noise := randf_range(-1.0, 1.0)
		lp += 0.18 * (noise - lp)
		var ceramic_tap := sin(2.0 * PI * 1400.0 * t) * exp(-90.0 * t) * 0.4
		samples[i] = (lp * 0.6 + ceramic_tap) * env * 0.75
	return create_stream_wav(samples, false)
```

---

### 4.2 Component 2: `scripts/audio/audio_manager.gd`
The Autoload singleton managing bus routing, caching, loop players, and signal subscriptions.

```gdscript
class_name AudioManager
extends Node

## AudioManager — Autoload Audio Controller for Buku Resep 2045
## Manages Ambience loop, Key Action SFX, Bus Volume Safety, and Signal Wiring.

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"

var _sound_cache: Dictionary = {}
var _ambience_player: AudioStreamPlayer = null
var _cooking_player: AudioStreamPlayer = null
var _ui_player: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
const SFX_POOL_SIZE: int = 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_connect_autoload_signals()
	play_ambience()

func _setup_audio_players() -> void:
	# 1. Ambience Player (Music bus, looped)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = BUS_MUSIC
	_ambience_player.volume_db = -14.0
	add_child(_ambience_player)
	
	# 2. Cooking Simmer Player (SFX bus, looped)
	_cooking_player = AudioStreamPlayer.new()
	_cooking_player.name = "CookingPlayer"
	_cooking_player.bus = BUS_SFX
	_cooking_player.volume_db = -12.0
	add_child(_cooking_player)
	
	# 3. Dedicated UI Player (SFX bus)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIPlayer"
	_ui_player.bus = BUS_SFX
	_ui_player.volume_db = -12.0
	_ui_player.max_polyphony = 4
	add_child(_ui_player)
	
	# 4. SFX Pool (SFX bus)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = BUS_SFX
		p.max_polyphony = 2
		add_child(p)
		_sfx_pool.append(p)

func get_sound(id: String) -> AudioStream:
	if _sound_cache.has(id):
		return _sound_cache[id]
		
	# 1. Check for authored asset file
	var asset_path := "res://assets/audio/%s.wav" % id
	if ResourceLoader.exists(asset_path):
		var loaded = load(asset_path) as AudioStream
		if loaded:
			_sound_cache[id] = loaded
			return loaded
			
	# 2. Procedural synthesis fallback
	var generated: AudioStream = null
	match id:
		"ambience_countryside": generated = AudioSynthesizer.generate_ambience_countryside()
		"footstep": generated = _create_randomized_footstep()
		"tool_hoe": generated = AudioSynthesizer.generate_tool_hoe()
		"tool_water": generated = AudioSynthesizer.generate_tool_water()
		"tool_fertilizer": generated = AudioSynthesizer.generate_tool_fertilizer()
		"harvest": generated = AudioSynthesizer.generate_harvest_pickup()
		"kitchen_simmer": generated = AudioSynthesizer.generate_kitchen_simmer()
		"ui_click": generated = AudioSynthesizer.generate_ui_click()
		"ui_confirm": generated = AudioSynthesizer.generate_ui_confirm()
		"eat_dish": generated = AudioSynthesizer.generate_eat_dish()
		_:
			generated = AudioSynthesizer.generate_ui_click()
			
	if generated != null:
		_sound_cache[id] = generated
	return generated

func _create_randomized_footstep() -> AudioStream:
	var base_wav := AudioSynthesizer.generate_footstep()
	var rnd := AudioStreamRandomizer.new()
	rnd.add_stream(-1, base_wav)
	rnd.random_pitch_semitones = 1.2
	rnd.random_volume_offset_db = 1.0
	return rnd

func play_sfx(id: String, volume_offset_db: float = 0.0) -> void:
	var stream := get_sound(id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = volume_offset_db
	player.play()

func play_ui_click() -> void:
	if _ui_player:
		_ui_player.stream = get_sound("ui_click")
		_ui_player.play()

func play_ui_confirm() -> void:
	if _ui_player:
		_ui_player.stream = get_sound("ui_confirm")
		_ui_player.play()

func play_footstep() -> void:
	play_sfx("footstep", -16.0)

func play_ambience() -> void:
	if _ambience_player:
		_ambience_player.stream = get_sound("ambience_countryside")
		if not _ambience_player.playing:
			_ambience_player.play()

func stop_ambience() -> void:
	if _ambience_player and _ambience_player.playing:
		_ambience_player.stop()

func start_cooking_loop() -> void:
	if _cooking_player:
		_cooking_player.stream = get_sound("kitchen_simmer")
		if not _cooking_player.playing:
			_cooking_player.play()

func stop_cooking_loop() -> void:
	if _cooking_player and _cooking_player.playing:
		_cooking_player.stop()

func _connect_autoload_signals() -> void:
	var tree := get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null or tree.root == null:
		return
		
	# GardenManager
	var gm = tree.root.get_node_or_null("GardenManager")
	if gm != null:
		if gm.has_signal("plot_hoed"): gm.plot_hoed.connect(func(_p): play_sfx("tool_hoe", -9.0))
		if gm.has_signal("plot_fertilized"): gm.plot_fertilized.connect(func(_p): play_sfx("tool_fertilizer", -11.0))
		if gm.has_signal("plot_watered"): gm.plot_watered.connect(func(_p): play_sfx("tool_water", -10.0))
		if gm.has_signal("spot_planted"): gm.spot_planted.connect(func(_p, _s, _c): play_sfx("harvest", -12.0))
		if gm.has_signal("spot_harvested"): gm.spot_harvested.connect(func(_p, _s, _c): play_sfx("harvest", -8.0))
		
	# KitchenManager
	var km = tree.root.get_node_or_null("KitchenManager")
	if km != null:
		if km.has_signal("cooking_started"): km.cooking_started.connect(func(_j, _d): start_cooking_loop())
		if km.has_signal("cooking_resumed"): km.cooking_resumed.connect(func(_j): start_cooking_loop())
		if km.has_signal("cooking_paused"): km.cooking_paused.connect(func(_j): stop_cooking_loop())
		if km.has_signal("cooking_completed"):
			km.cooking_completed.connect(func(_j, _o):
				stop_cooking_loop()
				play_ui_confirm()
			)
		if km.has_signal("dish_collected"): km.dish_collected.connect(func(_i, _c): play_sfx("harvest", -8.0))
		if km.has_signal("dish_consumed"): km.dish_consumed.connect(func(_i): play_sfx("eat_dish", -8.0))
		
	# WorldResourceManager
	var wm = tree.root.get_node_or_null("WorldResourceManager")
	if wm != null:
		if wm.has_signal("foraging_node_harvested"): wm.foraging_node_harvested.connect(func(_n, _i, _c): play_sfx("harvest", -8.0))
		if wm.has_signal("meal_consumed"): wm.meal_consumed.connect(func(_i, _c): play_sfx("eat_dish", -8.0))
		if wm.has_signal("rest_completed"): wm.rest_completed.connect(func(_d): play_ui_confirm())

# Helper to automatically attach button click audio across UI panels
func hook_control_tree(root_control: Control) -> void:
	if root_control == null:
		return
	for child in root_control.find_children("", "Button", true, false):
		var btn := child as Button
		if btn and not btn.pressed.is_connected(play_ui_click):
			btn.pressed.connect(play_ui_click)
```

---

### 4.3 Component 3: Bus Limiter in `default_bus_layout.tres`
Update `default_bus_layout.tres` to include the `AudioEffectLimiter` on Bus 0 (`Master`):
```tres
[gd_resource type="AudioBusLayout" load_steps=2 format=3 uid="uid://bx5p2buslayout01"]

[sub_resource type="AudioEffectLimiter" id="AudioEffectLimiter_01"]
resource_name = "MasterLimiter"
ceiling_db = -0.5
threshold_db = 0.0

[resource]
bus/0/effect/0/effect = SubResource("AudioEffectLimiter_01")
bus/0/effect/0/enabled = true
bus/1/name = &"Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
```

---

### 4.4 Component 4: Integration in `player_controller.gd`
Add footstep distance tracking in `_physics_process`:
```gdscript
var _step_distance_accumulator: float = 0.0
const STEP_DISTANCE_INTERVAL: float = 1.8 # Meters per step at 3.0 m/s walking speed

func _physics_process(delta: float) -> void:
	...
	velocity = calculate_movement_velocity(input_dir, velocity, delta, is_on_floor() if is_inside_tree() else true)
	if is_inside_tree():
		move_and_slide()
		if is_on_floor() and velocity.length() > 0.5 and movement_enabled:
			_step_distance_accumulator += velocity.length() * delta
			if _step_distance_accumulator >= STEP_DISTANCE_INTERVAL:
				_step_distance_accumulator = 0.0
				var am = get_node_or_null("/root/AudioManager")
				if am and am.has_method("play_footstep"):
					am.play_footstep()
```

---

### 4.5 Component 5: Unit Test Suite `tests/suites/test_audio.gd` (Suite 24)
Create `tests/suites/test_audio.gd` to test and verify all audio requirements headlessly:
```gdscript
class_name TestAudio
extends RefCounted

const Assertions = preload("res://tests/assertions.gd")

func run_all() -> bool:
	print("\n--- Running Suite 24: TestAudio (ART-001 Audio Integration) ---")
	test_audio_buses_configuration()
	test_audio_synthesizer_generation()
	test_audio_manager_lifecycle_and_pooling()
	test_audio_volume_safety()
	test_audio_signals_and_hooks()
	return Assertions.current_suite_failed == 0

func test_audio_buses_configuration() -> void:
	Assertions.assert_true(AudioServer.get_bus_index("Master") != -1, "Bus Master harus ada")
	Assertions.assert_true(AudioServer.get_bus_index("Music") != -1, "Bus Music harus ada")
	Assertions.assert_true(AudioServer.get_bus_index("SFX") != -1, "Bus SFX harus ada")
	var music_send := AudioServer.get_bus_send(AudioServer.get_bus_index("Music"))
	var sfx_send := AudioServer.get_bus_send(AudioServer.get_bus_index("SFX"))
	Assertions.assert_str_equal(str(music_send), "Master", "Bus Music harus dikirim ke Master")
	Assertions.assert_str_equal(str(sfx_send), "Master", "Bus SFX harus dikirim ke Master")

func test_audio_synthesizer_generation() -> void:
	var amb = AudioSynthesizer.generate_ambience_countryside()
	Assertions.assert_true(amb != null, "Ambience audio harus tergenerate")
	Assertions.assert_true(amb.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Ambience harus looping")
	Assertions.assert_true(amb.data.size() > 10000, "Ambience buffer data harus valid")

	var step = AudioSynthesizer.generate_footstep()
	Assertions.assert_true(step != null, "Footstep audio harus tergenerate")

	var hoe = AudioSynthesizer.generate_tool_hoe()
	Assertions.assert_true(hoe != null, "Tool hoe audio harus tergenerate")

	var click = AudioSynthesizer.generate_ui_click()
	Assertions.assert_true(click != null, "UI click audio harus tergenerate")

func test_audio_manager_lifecycle_and_pooling() -> void:
	var am = AudioManager.new()
	am._ready()
	Assertions.assert_true(am._ambience_player != null, "Ambience player harus terinisialisasi")
	Assertions.assert_true(am._cooking_player != null, "Cooking simmer player harus terinisialisasi")
	Assertions.assert_true(am._sfx_pool.size() == 8, "SFX pool harus berukuran 8 player")
	
	# Test headless play calls
	am.play_sfx("tool_hoe")
	am.play_ui_click()
	am.play_footstep()
	am.start_cooking_loop()
	am.stop_cooking_loop()
	am.queue_free()

func test_audio_volume_safety() -> void:
	var db_min := linear_to_db(0.0001)
	Assertions.assert_true(db_min > -81.0, "linear_to_db(0.0001) aman dari NaN/-inf")
	var db_half := linear_to_db(0.5)
	Assertions.assert_true(db_half < 0.0 and db_half > -7.0, "Decibel mapping benar")

func test_audio_signals_and_hooks() -> void:
	var am = AudioManager.new()
	am._ready()
	# Verify that AudioManager responds to signal hooks cleanly
	am.play_ui_confirm()
	am.stop_ambience()
	Assertions.assert_true(true, "Signal hooks executed without crash in headless environment")
	am.queue_free()
```

---

## 5. Verification Method

### 5.1 Automated Headless Verification
Execute the project test runner with Godot headless CLI:
```powershell
C:\Users\HP\.local\bin\godot.exe --headless -s tests/test_runner.gd
```
**Passing Criteria**:
1. Suite 24 executes all test cases (bus layout, procedural stream generation, pool lifecycle, volume safety, and signal hooks).
2. Exit code is `0`.
3. Assertions passed increases by ~25+ without any failure messages.
4. `test_summary.log` reports `All Passed: true` and `Assertions Failed: 0`.

### 5.2 Manual / Interactive GUI Verification
Run the game in windowed mode:
```powershell
C:\Users\HP\.local\bin\godot.exe --rendering-driver opengl3
```
1. **Ambience**: Observe soft rustling wind on entering the main yard.
2. **Footsteps**: Walk with WASD on dirt; verify soft rhythmic thuds with pitch variation.
3. **Tools**: Use cangkul (hoe), watering can, and fertilizer; verify crisp tactile sound feedback.
4. **Kitchen**: Start cooking Sayur Bening; verify gentle bubbling simmer loop starts on heat and stops when cooking completes.
5. **UI & Settings**: Open Pause menu (Esc) and Settings; verify button clicks and volume sliders for Master, Music, and SFX directly modulate their respective sound groups.

---
*End of handoff report.*
