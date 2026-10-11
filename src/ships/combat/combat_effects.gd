class_name CombatEffects
extends RefCounted

## Placeholder combat visuals: shot beams, impact flashes and explosions.
## Abstract on purpose: a beam that hits or misses is enough to read a fight.

## Colors may go above 1.0: they are HDR, so they glow.
const HIT_COLOR := Color(3.0, 1.2, 0.5, 0.9)
const MISS_COLOR := Color(1.0, 0.8, 0.5, 0.35)
const SHIELD_COLOR := Color(0.6, 1.2, 3.0, 0.8)
const ARMOR_COLOR := Color(3.0, 1.5, 0.4, 0.9)
const EXPLOSION_COLOR := Color(4.0, 2.0, 0.6, 1.0)

const BEAM_TIME := 0.2
## Thick enough to read at combat distances (a few pixels at 600 m); visuals are abstract anyway.
const BEAM_RADIUS := 2.5
const IMPACT_TIME := 0.25
const EXPLOSION_TIME := 0.9

static var _beam_mesh: CylinderMesh
static var _ball_mesh: SphereMesh


## A shot from `from` at `target`: a beam into the target on a hit, a beam past it on a miss.
static func shot(context: Node, from: Vector3, target: Ship, hit: bool,
		rng: RandomNumberGenerator) -> void:
	var center := target.global_position
	var direction := (center - from).normalized()
	var to: Vector3
	if hit:
		to = center - direction * target.radius * 0.8
	else:
		var side := direction.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = direction.cross(Vector3.RIGHT)
		side = side.normalized().rotated(direction, rng.randf() * TAU)
		to = center + side * target.radius * rng.randf_range(1.5, 3.0) + direction * target.radius * 6.0
	beam(context, from, to, HIT_COLOR if hit else MISS_COLOR)
	if hit:
		var color := SHIELD_COLOR if target.shield > 0.0 else ARMOR_COLOR
		FadingEffect.spawn(context, _ball(), color,
				Transform3D(Basis.from_scale(Vector3.ONE * target.radius * 0.5), to), IMPACT_TIME, 2.0)


static func beam(context: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var span := to - from
	var length := span.length()
	if length < 0.1:
		return
	var beam_basis := Basis(Quaternion(Vector3.UP, span / length))
	beam_basis.y *= length
	FadingEffect.spawn(context, _beam(), color, Transform3D(beam_basis, from + span * 0.5), BEAM_TIME)


static func explosion(context: Node, where: Vector3, size: float) -> void:
	FadingEffect.spawn(context, _ball(), EXPLOSION_COLOR,
			Transform3D(Basis.from_scale(Vector3.ONE * size), where), EXPLOSION_TIME, 4.0)
	FadingEffect.spawn(context, _ball(), Color(4, 4, 4, 1),
			Transform3D(Basis.from_scale(Vector3.ONE * size * 0.6), where), EXPLOSION_TIME * 0.4, 2.0)


static func _beam() -> CylinderMesh:
	if _beam_mesh == null:
		_beam_mesh = CylinderMesh.new()
		_beam_mesh.top_radius = BEAM_RADIUS
		_beam_mesh.bottom_radius = BEAM_RADIUS
		_beam_mesh.height = 1.0
		_beam_mesh.radial_segments = 6
		_beam_mesh.rings = 1
	return _beam_mesh


static func _ball() -> SphereMesh:
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 1.0
		_ball_mesh.height = 2.0
		_ball_mesh.radial_segments = 16
		_ball_mesh.rings = 8
	return _ball_mesh
