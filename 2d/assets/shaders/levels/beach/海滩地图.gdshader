shader_type canvas_item;
uniform vec4 color:source_color;
uniform sampler2D fast_noise:repeat_enable;
uniform sampler2D screen_content:hint_screen_texture;
uniform vec2 speed=vec2(0.03,0.07);
uniform float wave_length=2.0;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 texture_self=texture(TEXTURE,UV);
	vec2 uv=UV+speed*TIME;
	vec2 noise=texture(fast_noise,uv).rg;
	vec4 final_color=vec4(color.r,color.g,color.b,1)+vec4(noise.x,noise.y,1,1);
	final_color*=texture(screen_content,SCREEN_UV+noise*(wave_length/100.0));
	if (texture_self.a>0.0)
	{
		COLOR.rgb=final_color.rgb;
	}
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
