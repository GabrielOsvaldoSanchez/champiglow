
extends Node3D

@export var natural_color: Color = Color("#e8e3ce")
@export var glow_color: Color = Color("#55ff33")

@export_range(0.0, 5.0, 0.1)
var glow_strength: float = 2.0

@export_group("Variación natural")
@export_range(0.0, 0.4, 0.01)
var size_variation: float = 0.18

@onready var stem: Node3D = $Stem
@onready var stem_mesh: MeshInstance3D = $Stem/MeshInstance3D
@onready var cap: Node3D = $Cap
@onready var glow_light: OmniLight3D = $GlowLight

var glowing: bool = false
var growth_day: int = 1

var _adult_stem_scale: Vector3
var _adult_cap_position: Vector3
var _stem_base_y: float
var _stem_center_offset: float
var _stem_half_height: float

var _height_variation: float = 1.0
var _width_variation: float = 1.0
var _cap_variation: float = 1.0

var _adult_cap_scale: Vector3

var has_glowed: bool = false
var glow_days_elapsed: int = 0
var glow_progress: float = 0.0
var _stem_material: StandardMaterial3D

func _ready() -> void:
	_adult_stem_scale = stem.scale
	_adult_cap_position = cap.position
	
	_adult_cap_scale = cap.scale

	_height_variation = randf_range(
		1.0 - size_variation,
		1.0 + size_variation
	)

	_width_variation = randf_range(
		1.0 - size_variation,
		1.0 + size_variation
	)

	_cap_variation = randf_range(
		1.0 - size_variation,
		1.0 + size_variation
	)

	var bounds: AABB = stem_mesh.get_aabb()

	_stem_center_offset = (
		stem_mesh.position.y
		+ (bounds.position.y + bounds.size.y * 0.5)
		* stem_mesh.scale.y
	)

	_stem_half_height = (
		bounds.size.y * 0.5 * absf(stem_mesh.scale.y)
	)

	_stem_base_y = (
		stem.position.y
		+ stem.scale.y
		* (_stem_center_offset - _stem_half_height)
	)
	
	_stem_material = StandardMaterial3D.new()
	stem_mesh.material_override = _stem_material
	
	glow_light.light_color = glow_color
	glow_light.light_energy = 0.0
	glow_light.visible = false
	update_appearance()
	_apply_growth_stage()


# Control de apariencia.

func update_appearance() -> void:
	var current_color: Color = natural_color.lerp(
		glow_color,
		glow_progress
	)

	# Material del tallo.
	_stem_material.albedo_color = current_color
	_stem_material.roughness = 0.8
	_stem_material.emission_enabled = glow_progress > 0.001
	_stem_material.emission = glow_color
	_stem_material.emission_energy_multiplier = (
		glow_strength * glow_progress
	)

	# Material del sombrero.
	if cap.has_method("set_mushroom_appearance"):
		cap.set_mushroom_appearance(
			current_color,
			glow_strength * glow_progress
		)
		
	glow_light.visible = glow_progress > 0.001
	glow_light.light_energy = glow_strength * glow_progress


func set_glowing(enabled: bool) -> void:
	glowing = enabled
	update_appearance()


# Avanzar un día de crecimiento.


func advance_growth_day() -> void:
	growth_day += 1

	if growth_day == 14 and not has_glowed:
		has_glowed = true
		glowing = true
		glow_progress = 0.0

		update_appearance()
		print("Mycena comienza a iluminarse.")

	elif growth_day >= 17 and has_glowed and glowing:
		glowing = false
		glow_progress = 0.0

		update_appearance()
		print("Mycena ha terminado su fase bioluminiscente.")

	_apply_growth_stage()

	print("Mycena: día %d" % growth_day)





func _apply_growth_stage() -> void:
	# El tallo crece durante los días 1 al 9.
	var stem_progress: float = clampf(
		float(growth_day - 1) / 8.0,
		0.0,
		1.0
	)

	var stem_factor: float = lerpf(
		0.08,
		1.0,
		stem_progress
	)

	stem.scale = Vector3(
		_adult_stem_scale.x * _width_variation,
		_adult_stem_scale.y * stem_factor * _height_variation,
		_adult_stem_scale.z * _width_variation
	)

	# Mantener la base del tallo en su posición.
	stem.position.y = (
		_stem_base_y
		- stem.scale.y
		* (_stem_center_offset - _stem_half_height)
	)

	# Ajustar la altura del sombrero según el tallo.
	var target_cap_y := (_stem_base_y + (_adult_cap_position.y - _stem_base_y) * _height_variation)

	cap.position.y = lerpf(
		_stem_base_y,
		target_cap_y,
		stem_factor
	)

	# El sombrero aparece el día 10 y se expande hasta el 14.
	cap.visible = growth_day >= 10

	var cap_progress: float = clampf(float(growth_day - 10) / 4.0, 0.0, 1.0)

	var cap_factor: float = lerpf( 0.18, 1.0, cap_progress)

	cap.scale = _adult_cap_scale * _cap_variation * cap_factor
	
	
func _process(delta: float) -> void:
	if not has_glowed or not glowing:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var sky := current_scene.get_node_or_null("sky")
	if sky == null:
		return

	# No avanzar mientras el reloj esté detenido.
	if not bool(sky.get("auto_advance")):
		return

	var day_duration := float(sky.get("day_length"))
	if day_duration <= 0.0:
		return

	var previous_progress := glow_progress

	match growth_day:
		14:
			glow_progress = minf(
				glow_progress + delta / day_duration,
				1.0
			)

		15:
			glow_progress = 1.0

		16:
			glow_progress = maxf(
				glow_progress - delta / day_duration,
				0.0
			)

	if not is_equal_approx(previous_progress, glow_progress):
		update_appearance()
