class_name ToonSky
extends ShaderMaterial
## The painted sky material (world/toon_sky.gdshader), with the four colours named as on
## ProceduralSkyMaterial so the sea's and the porthole's code paints it the same way.

var sky_top_color := Color("#3F7FBF"):
	set(v):
		sky_top_color = v
		set_shader_parameter("top_color", v)
var sky_horizon_color := Color("#BFD8E8"):
	set(v):
		sky_horizon_color = v
		set_shader_parameter("horizon_color", v)
var ground_horizon_color := Color("#BFD8E8"):
	set(v):
		ground_horizon_color = v
		set_shader_parameter("ground_horizon_color", v)
var ground_bottom_color := Color("#1F4E79"):
	set(v):
		ground_bottom_color = v
		set_shader_parameter("ground_bottom_color", v)
## 0 clear .. 1 overcast; 0 under the water.
var clouds := 0.45:
	set(v):
		clouds = v
		set_shader_parameter("cloud_cover", v)
var night := false:
	set(v):
		night = v
		set_shader_parameter("night", 1.0 if v else 0.0)
		set_shader_parameter("cloud_color", Color("#3A4660") if v else Color("#FFFBF2"))
		set_shader_parameter("cloud_shade", Color("#1A2236") if v else Color("#9EB3CC"))


func _init() -> void:
	shader = preload("res://world/toon_sky.gdshader")
	for k in ["sky_top_color", "sky_horizon_color", "ground_horizon_color", "ground_bottom_color", "clouds", "night"]:
		set(k, get(k))
