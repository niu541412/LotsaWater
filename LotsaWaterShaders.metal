#include <metal_stdlib>
using namespace metal;

struct WaterVertex
{
	float2 position;
	float2 texCoord;
	float3 normal;
	float intensity;
};

struct WaterUniforms
{
	float2 waterSize;
};

struct RasterData
{
	float4 position [[position]];
	float2 wallpaperCoord;
	float2 reflectionCoord;
	float intensity;
};

static float2 sphereMapCoordinate(float3 eyeDirection,float3 eyeNormal)
{
	float3 reflected=reflect(eyeDirection,eyeNormal);
	float denominator=2.0*sqrt(dot(reflected.xy,reflected.xy)+
		(reflected.z+1.0)*(reflected.z+1.0));
	return denominator>0.000001
		? reflected.xy/denominator+0.5
		: float2(0.5);
}

vertex RasterData lotsaWaterVertex(
	uint vertexID [[vertex_id]],
	device const WaterVertex *vertices [[buffer(0)]],
	constant WaterUniforms &uniforms [[buffer(1)]])
{
	WaterVertex input=vertices[vertexID];
	RasterData output;

	// This is the same transform used by the former OpenGL fixed pipeline.
	output.position=float4(input.position.x*2.0-1.0,
		1.0-input.position.y*2.0,0.0,1.0);
	output.wallpaperCoord=input.texCoord;
	output.intensity=input.intensity;

	// Reproduce GL_SPHERE_MAP using the old model-view transform and its
	// inverse-transpose normal transform.
	float3 eyePosition=float3(
		-uniforms.waterSize.x+2.0*uniforms.waterSize.x*input.position.x,
		 uniforms.waterSize.y-2.0*uniforms.waterSize.y*input.position.y,
		-5.0);
	float3 eyeNormal=normalize(float3(
		input.normal.x/(2.0*uniforms.waterSize.x),
		-input.normal.y/(2.0*uniforms.waterSize.y),
		input.normal.z/10.0));
	float3 eyeDirection=normalize(eyePosition);
	float2 rippleReflection=sphereMapCoordinate(eyeDirection,eyeNormal);
	// Keep generated coordinates in the normal sphere-map range.  Amplifying
	// these coordinates makes clamp-to-edge stretch the texture borders into
	// horizontal and vertical bands.
	output.reflectionCoord=rippleReflection;

	return output;
}

fragment float4 lotsaWaterFragment(
	RasterData input [[stage_in]],
	texture2d<float> wallpaper [[texture(0)]],
	texture2d<float> reflection [[texture(1)]])
{
	constexpr sampler linearSampler(coord::normalized,
		address::clamp_to_edge,
		filter::linear);
	float4 base=wallpaper.sample(linearSampler,input.wallpaperCoord);
	float4 shine=reflection.sample(linearSampler,input.reflectionCoord);
	return float4(clamp(base.rgb*input.intensity+shine.rgb,0.0,1.0),1.0);
}
