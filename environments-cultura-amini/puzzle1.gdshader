shader_type canvas_item;

uniform float strength : hint_range(0.0, 5.0) = 3.0;   
uniform float radius   : hint_range(0.0, 1.5) = 0.55;  
uniform float softness : hint_range(0.001, 1.0) = 0.30; 
uniform float power    : hint_range(0.5, 6.0) = 3.0;   
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 p = uv - center;

    
    vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
    float aspect = viewport_size.x / viewport_size.y;
    p.x *= aspect;

    float d = length(p);

    float v = smoothstep(radius, radius + softness, d); 
    v = pow(v, power);

    float a = clamp(v * strength, 0.0, 1.0);

    COLOR = vec4(0.0, 0.0, 0.0, a);
}