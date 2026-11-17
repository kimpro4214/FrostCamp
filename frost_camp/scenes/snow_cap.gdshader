shader_type spatial;
// 모델 원래 색(텍스처 × 색) 위에, 위를 향한 면만 눈으로 덮는다.
// 면이 하늘을 볼수록(세계 법선 y가 클수록) 눈이 된다. 경계는 세계 위치로 조금씩 흔들어 자연스럽게 한다.

// 텍스처가 없는 모델(단색 재질)은 흰색으로 두어 색만 쓴다.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
// 원래 재질의 금속성(Kenney 모델은 1이라 색이 짙게 보인다). 눈은 금속성 0이다.
uniform float metallic = 0.0;
uniform vec4 snow_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
// 세계 법선 y가 이 값을 넘으면 눈이 쌓인다
uniform float snow_from = 0.55;
// 경계를 흔드는 정도
uniform float edge_jitter = 0.12;

float hash(vec3 p) {
	return fract(sin(dot(floor(p), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(albedo_texture, UV) * albedo_color;
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float from = snow_from + (hash(world_pos * 2.5) - 0.5) * edge_jitter;
	float snow = smoothstep(from, from + 0.05, world_normal.y);
	ALBEDO = mix(base.rgb, snow_color.rgb, snow);
	METALLIC = mix(metallic, 0.0, snow);
	ROUGHNESS = 1.0;
}
