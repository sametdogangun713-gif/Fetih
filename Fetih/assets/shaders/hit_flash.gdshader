shader_type canvas_item;
// Vuruş flaşı: bölüğün askerlerini kısa süre flash_color rengine boyar.
// SquadView her bölük için bu shader'dan bir ShaderMaterial kopyası tutar ve "flash"
// değerini her karede ayarlar (1 = tamamen beyaz, 0 = normal). Saydam pikseller saydam
// kalır: sadece rengi değişir, şekil aynı. Böylece ayrı bir beyaz siluet dokusuna gerek kalmaz.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// fragment() içinde COLOR = doku rengi x köşe (vertex) rengi. Sadece rgb karıştırılır.
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
