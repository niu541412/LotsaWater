void main()
{
    vec4 surface = texture2D(u_surface_texture,
        vec2(v_tex_coord.x, 1.0 - v_tex_coord.y));
    gl_FragColor = vec4(vec3(surface.b), 1.0);
}
