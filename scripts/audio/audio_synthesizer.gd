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

# 11. Heat Stall Warning - 0.30s
static func generate_heat_stall() -> AudioStreamWAV:
	var count := int(0.30 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := exp(-10.0 * t)
		var freq := 440.0 - (110.0 * (t / 0.30)) # Descending warning 440Hz -> 330Hz
		var tone := sin(2.0 * PI * freq * t) * 0.6
		samples[i] = tone * env * 0.8
	return create_stream_wav(samples, false)
