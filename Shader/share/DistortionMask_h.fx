//-----------------------------------------------------------------------------
// File: Distortion.fx
//
// Desc: Distortion 효과 적용
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------
shared float4 g_DistortionDir = {-0.05f, 0.02f, 0.03f, 0.02f*0.7f};
shared float4 g_DistortionInfo = {0.1f, 0.1f, 1.0f, 0.0f}; //x,y: Speed, z: Scale, w: Range
shared float g_fDistortionTime = 1;
shared float g_fDistortionFarZ = 0.f;




sampler samBumpMap : register(s4);			// AS_NORMALMAP


float2 GetDistortion( in float2 vTexcoord)
{
  float4 tex = float4(vTexcoord,vTexcoord) + frac(g_DistortionDir*g_DistortionInfo.xxyy*g_fDistortionTime);
  float4 bump = float4( tex2D(samBumpMap, tex.xy).xy, tex2D(samBumpMap, tex.zw).xy);
  bump  = bump * 2.0f -1.0f;
  
  //g_Info.z => Distortion Scale
  float2 sumedBump = ((bump.xy + bump.zw)/2.0f) * g_DistortionInfo.z;
	
	return sumedBump.xy;
}