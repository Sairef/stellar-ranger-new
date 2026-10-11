class_name FadingEffect
extends MeshInstance3D

## A short-lived glowing shape that fades out (and optionally grows), then frees itself.
## Used for shot beams, impact flashes and explosions.

var lifetime := 0.2
## Scale at the end of the lifetime, relative to the start.
var end_scale := 1.0

var _age := 0.0
var _material: StandardMaterial3D
var _start_alpha := 1.0
var _start_basis := Basis.IDENTITY


## Creates an effect in the scene that `context` belongs to.
static func spawn(context: Node, shape: Mesh, color: Color, where: Transform3D, p_lifetime: float,
		p_end_scale := 1.0) -> FadingEffect:
	var effect := FadingEffect.new()
	effect.mesh = shape
	effect.lifetime = p_lifetime
	effect.end_scale = p_end_scale
	effect._material = StandardMaterial3D.new()
	effect._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	effect._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect._material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	effect._material.cull_mode = BaseMaterial3D.CULL_DISABLED
	effect._material.albedo_color = color
	effect._start_alpha = color.a
	effect.material_override = effect._material
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.top_level = true
	effect.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root_for(context).add_child(effect)
	effect.global_transform = where
	effect._start_basis = where.basis
	return effect


## Where short-lived things (effects, wrecks) go: the current scene, or the tree root.
static func root_for(context: Node) -> Node:
	var tree := context.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root


func _process(delta: float) -> void:
	_age += delta
	var t := _age / lifetime
	if t >= 1.0:
		queue_free()
		return
	_material.albedo_color.a = _start_alpha * (1.0 - t)
	if end_scale != 1.0:
		global_basis = _start_basis * lerpf(1.0, end_scale, t)
