class_name Porthole
extends Node3D
## A round brass-rimmed window in the hull side. Dark glass until the local player looks at
## it from close by; then PortholeEye shows the water outside it, live.

const RADIUS := 0.24
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D view : source_color, filter_linear;
uniform bool live = false;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	if (r > 1.0) {
		discard;
	}
	vec3 col = live ? texture(view, UV).rgb : vec3(0.04, 0.16, 0.2);
	col = mix(col, vec3(0.65, 0.88, 0.92), 0.06 + 0.1 * smoothstep(0.2, -0.6, c.x + c.y)); // a glint on the glass
	col *= 1.0 - 0.4 * smoothstep(0.55, 1.0, r);
	ALBEDO = col;
}
"""

static var _shader: Shader

var side := 1.0 ## +1 starboard wall, -1 port
var glass: ShaderMaterial


static func create(pos: Vector3, wall_side: float) -> Porthole:
	var p := Porthole.new()
	p.side = wall_side
	p.position = pos
	return p


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLASS_SHADER
	glass = ShaderMaterial.new()
	glass.shader = _shader
	# Faces into the boat: a quad's +Z turned to point inboard, its right hand to the viewer's right.
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	pane.mesh = quad
	pane.material_override = glass
	pane.rotation.y = -side * PI / 2.0
	add_child(pane)
	# The brass ring and its bolts.
	var ring := Build.cyl(self, RADIUS + 0.06, 0.06, Vector3(side * 0.02, 0, 0), Color("#C9A04A"), Vector3.RIGHT)
	ring.material_override = Build.mat(Color("#C9A04A"))
	Build.cyl(self, RADIUS + 0.005, 0.07, Vector3(side * 0.01, 0, 0), Color("#1A2A2A"), Vector3.RIGHT)
	pane.position.x = -side * 0.03
	for k in 8:
		var a := k * TAU / 8.0
		Build.sphere(self, 0.018, Vector3(-side * 0.02, sin(a) * (RADIUS + 0.035), cos(a) * (RADIUS + 0.035)), Color("#8A6A2A"))


func set_view(tex: Texture2D) -> void:
	glass.set_shader_parameter("live", tex != null)
	glass.set_shader_parameter("view", tex)
