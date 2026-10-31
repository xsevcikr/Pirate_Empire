class_name TitleLogo
extends Label
## "PIRATE EMPIRE" in chunky cartoon letters: a sunset gradient from gold to orange, a thick dark outline and a drop
## shadow. Font: Luckiest Guy by Astigmatic (Apache 2.0, assets/fonts).

const FONT: FontFile = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const SHADER: String = """
shader_type canvas_item;
uniform vec3 top_col = vec3(1.0, 0.93, 0.35);
uniform vec3 bottom_col = vec3(0.98, 0.42, 0.08);
uniform float y0 = 0.0;
uniform float y1 = 100.0;
varying vec4 vcol;
varying float ly;
void vertex() {
	vcol = COLOR;
	ly = VERTEX.y;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float fill = step(0.9, vcol.g);  // the glyph fill is drawn white; outline and shadow keep their own colours
	vec3 g = mix(top_col, bottom_col, smoothstep(y0, y1, ly));
	COLOR = vec4(mix(vcol.rgb, g, fill), t.a * vcol.a);
}
"""


func _init(text_size: int = 150) -> void:
	text = "PIRATE EMPIRE"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = FONT
	ls.font_size = text_size
	ls.font_color = Color.WHITE
	ls.outline_size = int(text_size * 0.2)
	ls.outline_color = Color(0.36, 0.11, 0.05)
	ls.shadow_size = int(text_size * 0.12)
	ls.shadow_color = Color(0.1, 0.03, 0.02, 0.75)
	ls.shadow_offset = Vector2(0.0, text_size * 0.07)
	label_settings = ls
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	material = m
	resized.connect(_fit_gradient)


## The gradient runs over the cap height of the letters, wherever the label sits in its box.
func _fit_gradient() -> void:
	var fs: float = float(label_settings.font_size)
	var mid: float = size.y * 0.5
	(material as ShaderMaterial).set_shader_parameter("y0", mid - fs * 0.38)
	(material as ShaderMaterial).set_shader_parameter("y1", mid + fs * 0.3)
