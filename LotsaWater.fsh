void main()
{
    vec4 surface = texture2D(u_surface_texture,
        vec2(v_tex_coord.x, 1.0 - v_tex_coord.y));
    vec2 slope = surface.rg - vec2(0.5);
    float height = (surface.b - 0.5) * 0.25;
    float slopeLength = length(slope);
    vec2 wallpaperCoord = v_tex_coord;

    if (slopeLength > 0.00001) {
        float normalLength = length(vec3(slope, 1.0));
        float cosA = 1.0 / normalLength;
        float sinA = sqrt(max(0.0, 1.0 - cosA * cosA));
        float sinB = sinA / 1.333;
        float cosB = sqrt(max(0.0, 1.0 - sinB * sinB));
        float displacement = (sinA * cosB - cosA * sinB) *
            (height + u_water_depth);
        wallpaperCoord.x -= slope.x / slopeLength * displacement / u_water_size.x;
        wallpaperCoord.y += slope.y / slopeLength * displacement / u_water_size.y;
    }

    vec2 croppedCoord = u_texture_crop.xy + wallpaperCoord * u_texture_crop.zw;
    vec4 base = texture2D(u_texture, clamp(croppedCoord, 0.0, 1.0));
    float intensity = clamp(1.0 - (slope.x + slope.y) * 3.0, 0.0, 1.0) * u_fade;

    vec3 eyePosition = normalize(vec3(
        -u_water_size.x + 2.0 * u_water_size.x * v_tex_coord.x,
        -u_water_size.y + 2.0 * u_water_size.y * v_tex_coord.y,
        -5.0));
    vec3 eyeNormal = normalize(vec3(
        slope.x / (2.0 * u_water_size.x),
        -slope.y / (2.0 * u_water_size.y), 0.1));
    vec3 reflected = reflect(eyePosition, eyeNormal);
    float denominator = 2.0 * length(vec3(reflected.xy, reflected.z + 1.0));
    vec2 reflectionCoord = denominator > 0.00001
        ? reflected.xy / denominator + vec2(0.5) : vec2(0.5);
    vec4 shine = texture2D(u_reflection_texture, reflectionCoord);
    gl_FragColor = vec4(base.rgb * intensity + shine.rgb, 1.0);
}
