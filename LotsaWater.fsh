void main()
{
    vec2 uv = v_tex_coord;
    vec2 mapCoord = vec2(uv.x, 1.0 - uv.y);
    vec4 refraction = texture2D(u_refraction_texture, mapCoord);
    vec4 reflectionMap = texture2D(u_reflection_map_texture, mapCoord);
    vec2 wallpaperCoord = refraction.rg * 2.0 - 0.5;
    wallpaperCoord.y = 1.0 - wallpaperCoord.y;
    wallpaperCoord = u_texture_crop.xy + wallpaperCoord * u_texture_crop.zw;
    vec4 base = texture2D(u_texture, wallpaperCoord);
    vec4 shine = texture2D(u_reflection_texture, reflectionMap.rg);
    gl_FragColor = vec4(clamp(base.rgb * refraction.b + shine.rgb, 0.0, 1.0), 1.0);
}
