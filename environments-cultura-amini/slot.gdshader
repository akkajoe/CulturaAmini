shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.75, 1.0, 0.95, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.2;
uniform float radius_px : hint_range(0.0, 100.0) = 22.0;
uniform float falloff_pow : hint_range(0.001, 8.0) = 2.5; // higher = faster fade
uniform float glow_max_alpha : hint_range(0.0, 1.0) = 0.85;

float w(float t) { // weight curve: strong near sprite, fades out
    return pow(clamp(1.0 - t, 0.0, 1.0), falloff_pow);
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec2 px = TEXTURE_PIXEL_SIZE;

    // Sample alpha in a soft disk (12 taps). More "bloom", less "outline".
    float sum = 0.0;
    float wsum = 0.0;

    // normalized offsets (rough Poisson-ish disk)
    vec2 offs[12] = vec2[](
        vec2( 1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0,  1.0), vec2(0.0, -1.0),
        vec2( 0.707,  0.707), vec2(-0.707,  0.707), vec2( 0.707, -0.707), vec2(-0.707, -0.707),
        vec2( 0.35,  0.94), vec2(-0.35,  0.94), vec2( 0.94, -0.35), vec2(-0.94, -0.35)
    );

    for (int i = 0; i < 12; i++) {
        // spread samples across the radius
        float t = float(i) / 11.0;             // 0..1
        float d = mix(1.0, radius_px, t);      // 1px .. radius
        vec2 o = offs[i] * px * d;

        float a = texture(TEXTURE, UV + o).a;
        float wt = w(d / max(radius_px, 0.001));
        sum += a * wt;
        wsum += wt;
    }

    float blurred_a = (wsum > 0.0) ? (sum / wsum) : 0.0;

    // Only glow outside the sprite (prevents recoloring the mushroom)
    float halo = blurred_a * (1.0 - base.a);

    float glow_a = clamp(halo * glow_strength, 0.0, glow_max_alpha);
    vec3 glow_rgb = glow_color.rgb * glow_a;

    COLOR = vec4(base.rgb + glow_rgb, max(base.a, glow_a));
}