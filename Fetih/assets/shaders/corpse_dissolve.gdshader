shader_type canvas_item;
// Düşen askerin bedeni: önce bir an beyaz parlar, yerde kalır, sonra piksel piksel çözülür.
// Her ceset ayrı bir çizim komutu ama hepsi tek CanvasItem'da (BattleFx'in ceset katmanı);
// cesede özel değerler çizim renginde (köşe/vertex rengi) taşınır:
//   r = beyazlık (1: bembeyaz siluet, 0: normal)
//   a = kalan miktar (1: tam, 0: tamamen çözüldü)
// Böylece yüzlerce ceset için ayrı material gerekmez, hepsi tek seferde çizilir.

uniform vec3 tint : source_color = vec3(0.55, 0.5, 0.5);  // ölü bedenin soluk tonu
uniform vec3 edge_color : source_color = vec3(0.984, 0.725, 0.329);  // kor rengi (Resurrect 64 #fbb954)
uniform float edge_width = 0.12;

varying vec4 data;

void vertex() {
	data = COLOR;  // vertex() içindeki COLOR = çizim komutunun rengi (dokudan önce)
}

// Sözde rastgele 0-1: her doku pikseli için sabit bir değer (çözülme sırası).
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// UV / TEXTURE_PIXEL_SIZE = doku pikselinin koordinatı: çözülme sprite'ın kendi
	// pikselleriyle olur, ekran pikseliyle değil (piksel sanat bütünlüğü).
	float n = hash(floor(UV / TEXTURE_PIXEL_SIZE));
	float keep = data.a;
	if (n > keep) {
		discard;
	}
	vec3 rgb = mix(tex.rgb * tint, vec3(1.0), data.r);
	if (keep < 0.999 && n > keep - edge_width) {
		rgb = edge_color;
	}
	COLOR = vec4(rgb, tex.a);
}
