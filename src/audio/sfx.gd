class_name Sfx
extends RefCounted

## Placeholder sound effects, synthesized in code the first time each one is needed (there are no
## audio files): shots, hits on the shield and on the armor, explosions, modules, the alert, a
## reward, a refusal. Abstract on purpose, like the visuals.
## play_at() puts a sound into the 3D world: full volume within UNIT_SIZE of the camera, fading
## farther away, not played at all beyond MAX_DISTANCE. play_ui() plays one flat, for the player's
## own events. At most MAX_VOICES sounds play at once, so a big battle does not turn into noise.

const MIX_RATE := 22050
const MAX_DISTANCE := 3000.0
const UNIT_SIZE := 250.0
const MAX_VOICES := 24
const VOICES_GROUP := &"sfx_voices"

## Synthesized streams by name, made on first use.
static var _streams := {}


## Plays `sound` at `where` in the world that `context` belongs to.
static func play_at(context: Node, sound: StringName, where: Vector3, volume_db := 0.0,
		pitch := 1.0) -> void:
	if not _has_free_voice(context):
		return
	var camera := context.get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_to(where) > MAX_DISTANCE:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound)
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.top_level = true
	_start(context, player)
	player.global_position = where
	player.play()


## Plays `sound` flat, the same everywhere (for the player's own events).
static func play_ui(context: Node, sound: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	if not _has_free_voice(context):
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	_start(context, player)
	player.play()


## The synthesized stream for `sound` (see the generators below).
static func stream(sound: StringName) -> AudioStreamWAV:
	if not _streams.has(sound):
		var samples: PackedFloat32Array
		match sound:
			&"shot":
				samples = _shot()
			&"hit_shield":
				samples = _hit_shield()
			&"hit_armor":
				samples = _hit_armor()
			&"explosion":
				samples = _explosion()
			&"afterburner":
				samples = _afterburner()
			&"shield_boost":
				samples = _shield_boost()
			&"alert":
				samples = _alert()
			&"reward":
				samples = _reward()
			&"denied":
				samples = _denied()
			_:
				push_error("Unknown sound: %s" % sound)
				samples = PackedFloat32Array([0.0])
		_streams[sound] = _to_wav(samples)
	return _streams[sound]


static func _has_free_voice(context: Node) -> bool:
	return context.is_inside_tree() \
			and context.get_tree().get_node_count_in_group(VOICES_GROUP) < MAX_VOICES


## Adds a voice to the scene; it frees itself once the sound is over (by a timer: without an audio
## device, e.g. in headless tests, players never report that they finished).
static func _start(context: Node, player: Node) -> void:
	player.add_to_group(VOICES_GROUP)
	FadingEffect.root_for(context).add_child(player)
	var length: float = player.stream.get_length() / player.pitch_scale + 0.1
	context.get_tree().create_timer(length).timeout.connect(player.queue_free)


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


# --- Generators: samples in -1..1 -------------------------------------------------------------

static func _samples(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	return samples


## A zap: a square-ish tone sweeping down fast.
static func _shot() -> PackedFloat32Array:
	var samples := _samples(0.13)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		phase += TAU * lerpf(1500.0, 320.0, sqrt(t)) / MIX_RATE
		var tone := clampf(sin(phase) * 3.0, -1.0, 1.0)
		samples[i] = tone * 0.3 * (1.0 - t) * minf(1.0, i / 60.0)
	return samples


## A soft electric fizz with a high ring.
static func _hit_shield() -> PackedFloat32Array:
	var samples := _samples(0.2)
	var noise := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.5)
		phase += TAU * lerpf(1900.0, 1100.0, t) / MIX_RATE
		samples[i] = (noise * 0.35 + sin(phase) * 0.25) * pow(1.0 - t, 2.0)
	return samples


## A dull thud with a crunch.
static func _hit_armor() -> PackedFloat32Array:
	var samples := _samples(0.24)
	var noise := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.15)
		phase += TAU * lerpf(150.0, 55.0, t) / MIX_RATE
		samples[i] = (sin(phase) * 0.6 + noise * 0.8) * pow(1.0 - t, 3.0)
	return samples


## A low rumbling blast that dies down slowly.
static func _explosion() -> PackedFloat32Array:
	var samples := _samples(1.4)
	var noise := 0.0
	var rumble := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		noise = lerpf(noise, randf_range(-1.0, 1.0), lerpf(0.25, 0.03, t))
		rumble = lerpf(rumble, randf_range(-1.0, 1.0), 0.01)
		phase += TAU * 48.0 / MIX_RATE
		var body := noise * 0.9 + rumble * 3.0 + sin(phase) * 0.3
		samples[i] = body * exp(-3.5 * t) * minf(1.0, i / 40.0)
	return samples


## A roaring whoosh that swells up.
static func _afterburner() -> PackedFloat32Array:
	var samples := _samples(0.8)
	var noise := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		noise = lerpf(noise, randf_range(-1.0, 1.0), lerpf(0.04, 0.35, t))
		samples[i] = noise * 0.9 * sin(PI * minf(1.0, t * 1.4)) * (1.0 - t * 0.5)
	return samples


## A rising, wavering chime.
static func _shield_boost() -> PackedFloat32Array:
	var samples := _samples(0.5)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		var freq := lerpf(300.0, 1200.0, t) * (1.0 + 0.04 * sin(t * TAU * 9.0))
		phase += TAU * freq / MIX_RATE
		samples[i] = sin(phase) * 0.35 * sin(PI * t)
	return samples


## Two-tone beeps, twice.
static func _alert() -> PackedFloat32Array:
	var samples := _samples(0.9)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var slot := int(t / 0.22)
		var within := fmod(t, 0.22)
		phase += TAU * (880.0 if slot % 2 == 0 else 620.0) / MIX_RATE
		var on := within < 0.16
		samples[i] = clampf(sin(phase) * 2.0, -1.0, 1.0) * 0.18 if on else 0.0
	return samples


## A bright coin-like ding.
static func _reward() -> PackedFloat32Array:
	var samples := _samples(0.4)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		phase += TAU * (1320.0 if t < 0.08 else 1760.0) / MIX_RATE
		var since := t if t < 0.08 else t - 0.08
		samples[i] = sin(phase) * 0.3 * exp(-8.0 * since)
	return samples


## A short low buzz: "no".
static func _denied() -> PackedFloat32Array:
	var samples := _samples(0.18)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / samples.size()
		phase += TAU * 110.0 / MIX_RATE
		samples[i] = clampf(sin(phase) * 4.0, -1.0, 1.0) * 0.15 * (1.0 - t)
	return samples
