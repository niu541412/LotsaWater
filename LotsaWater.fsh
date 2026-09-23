void main()
{
    vec2 uv = v_tex_coord;
    vec4 surface = texture2D(u_water_texture, vec2(uv.x, 1.0 - uv.y));
    vec3 normal = vec3(surface.xy, 1.0);

    float normalLength = length(normal);
    float cosA = normal.z / normalLength;
    float sinA = sqrt(max(0.0, 1.0 - cosA * cosA));
    float sinB = sinA / 1.333;
    float cosB = sqrt(max(0.0, 1.0 - sinB * sinB));
    float sinAB = sinA * cosB - cosA * sinB;
    float slopeLength = length(normal.xy);

    vec2 wallpaperCoord = uv;
    if (slopeLength > 0.000001) {
        float depth = surface.z + u_water_depth;
        wallpaperCoord -= normal.xy / slopeLength * sinAB * depth / u_water_size;
    }
    wallpaperCoord = u_texture_crop.xy + wallpaperCoord * u_texture_crop.zw;

    vec3 eyePosition = vec3(
        -u_water_size.x + 2.0 * u_water_size.x * uv.x,
         u_water_size.y - 2.0 * u_water_size.y * uv.y,
        -5.0);
    vec3 eyeNormal = normalize(vec3(
        normal.x / (2.0 * u_water_size.x),
       -normal.y / (2.0 * u_water_size.y),
        normal.z / 10.0));
    vec3 reflected = reflect(normalize(eyePosition), eyeNormal);
    float denominator = 2.0 * sqrt(dot(reflected.xy, reflected.xy) +
        (reflected.z + 1.0) * (reflected.z + 1.0));
    vec2 reflectionCoord = denominator > 0.000001
        ? reflected.xy / denominator + 0.5
        : vec2(0.5);

    float intensity = clamp(1.0 - (normal.x + normal.y) * 3.0, 0.0, 1.0) * u_fade;
    vec4 base = texture2D(u_texture, wallpaperCoord);
    vec4 shine = texture2D(u_reflection_texture, reflectionCoord);
    gl_FragColor = vec4(clamp(base.rgb * intensity + shine.rgb, 0.0, 1.0), 1.0);
}
