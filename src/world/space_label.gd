@tool
class_name SpaceLabel
extends RefCounted

## Factory for the floating name labels above ships and asteroids.
## Labels keep a constant size on screen and are visible through other objects.


static func create(text: String, object_radius: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.pixel_size = 0.0008
	label.font_size = 28
	label.outline_size = 8
	label.modulate = Color(1.0, 1.0, 1.0, 0.85)
	label.position = Vector3(0.0, object_radius * 1.5, 0.0)
	return label
