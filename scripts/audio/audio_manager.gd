class_name AudioManagerClass
extends Node

const AudioSynthesizer = preload("res://scripts/audio/audio_synthesizer.gd")

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
		
	# 1. Check for authored asset file (support drop-in CC0 audio files)
	var asset_wav := "res://assets/audio/%s.wav" % id
	var asset_ogg := "res://assets/audio/%s.ogg" % id
	if ResourceLoader.exists(asset_wav):
		var loaded = load(asset_wav) as AudioStream
		if loaded:
			_sound_cache[id] = loaded
			return loaded
	elif ResourceLoader.exists(asset_ogg):
		var loaded_ogg = load(asset_ogg) as AudioStream
		if loaded_ogg:
			_sound_cache[id] = loaded_ogg
			return loaded_ogg
			
	# 2. Procedural synthesis fallback (16-bit 22.05kHz PCM)
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
		"heat_stall": generated = AudioSynthesizer.generate_heat_stall()
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
	if stream == null or _sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
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
		
	# GardenManager wiring
	var gm = tree.root.get_node_or_null("GardenManager")
	if gm != null:
		if gm.has_signal("plot_hoed"):
			gm.plot_hoed.connect(func(_p): play_sfx("tool_hoe", -9.0))
		if gm.has_signal("plot_fertilized"):
			gm.plot_fertilized.connect(func(_p): play_sfx("tool_fertilizer", -11.0))
		if gm.has_signal("plot_watered"):
			gm.plot_watered.connect(func(_p): play_sfx("tool_water", -10.0))
		if gm.has_signal("spot_planted"):
			gm.spot_planted.connect(func(_p, _s, _c): play_sfx("harvest", -12.0))
		if gm.has_signal("spot_harvested"):
			gm.spot_harvested.connect(func(_p, _s, _c): play_sfx("harvest", -8.0))
		
	# KitchenManager wiring
	var km = tree.root.get_node_or_null("KitchenManager")
	if km != null:
		if km.has_signal("cooking_started"):
			km.cooking_started.connect(func(_j, _d): start_cooking_loop())
		if km.has_signal("cooking_resumed"):
			km.cooking_resumed.connect(func(_j): start_cooking_loop())
		if km.has_signal("cooking_paused"):
			km.cooking_paused.connect(func(_j): stop_cooking_loop())
		if km.has_signal("cooking_completed"):
			km.cooking_completed.connect(func(_j, _o):
				stop_cooking_loop()
				play_ui_confirm()
			)
		if km.has_signal("heat_stalled"):
			km.heat_stalled.connect(func(_msg): play_sfx("heat_stall", -8.0))
		if km.has_signal("dish_collected"):
			km.dish_collected.connect(func(_i, _c): play_sfx("harvest", -8.0))
		if km.has_signal("dish_consumed"):
			km.dish_consumed.connect(func(_i): play_sfx("eat_dish", -8.0))
		
	# WorldResourceManager wiring
	var wm = tree.root.get_node_or_null("WorldResourceManager")
	if wm != null:
		if wm.has_signal("foraging_node_harvested"):
			wm.foraging_node_harvested.connect(func(_n, _i, _c): play_sfx("harvest", -8.0))
		if wm.has_signal("meal_consumed"):
			wm.meal_consumed.connect(func(_i, _c): play_sfx("eat_dish", -8.0))
		if wm.has_signal("rest_completed"):
			wm.rest_completed.connect(func(_d): play_ui_confirm())

# Helper to automatically attach button click audio across UI panels
func hook_control_tree(root_control: Control) -> void:
	if root_control == null:
		return
	for child in root_control.find_children("", "Button", true, false):
		var btn := child as Button
		if btn and not btn.pressed.is_connected(play_ui_click):
			btn.pressed.connect(play_ui_click)
