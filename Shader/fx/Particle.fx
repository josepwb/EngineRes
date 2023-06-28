///////////////////////////////////////////////////////////////////////////////

#include "DistortionMask_h.fx"

sampler DiffuseMap : register(s0);
sampler DepthBufferMap : register(s2);
sampler IlluminationMap : register(s5);

shared matrix	g_matWorld;
shared matrix	g_matWorldView;
shared matrix	g_matWorldViewProj;

shared float4	g_vResolution;
shared float	g_fFarZ;	

shared float	g_fAlphaRef = 0;

shared float 	g_vIlluminationScale = 1;

shared float 	g_fDepthBiasBlendDist = 20.0f;

shared float 	g_fAttenuationBegin; // Distortion Param

shared float4	g_vFogFactor;   // x : near, y : far, z : dist , w : factor (multiply)
shared float3	g_vFogColor;

///////////////////////////////////////////////////////////////////////////////

struct VSINPUT
{
	float4 vPosition	: POSITION;
	float4 vColor		: COLOR;
	float2 vTexCoord0 	: TEXCOORD0;
	float3 vTexCoord1 	: TEXCOORD1;
};

struct VSOUTPUT
{
	float4 vPosition	: POSITION;
	float4 vColor		: COLOR;
	float2 vTexCoord0 	: TEXCOORD0;
#ifdef MULTI_LAYER_BLENDING
	float3 vTexCoord1 	: TEXCOORD1;
#endif
#if SOFT_PARTICLE == 1 || DISTORTION_MASKING == 1
	float4 vVPOS		: TEXCOORD2;
#endif
	float  fFog			: FOG;
};


float4 ConvertToVPos( float4 p )
{
   return float4( 0.5*( float2(p.x + p.w, p.w - p.y) + p.w * (1.f / g_vResolution.xy) ), p.zw);
}

VSOUTPUT VSMAIN( VSINPUT input )
{
	VSOUTPUT output = (VSOUTPUT)0;

	output.vPosition = mul( input.vPosition, g_matWorldViewProj );
	output.vColor = input.vColor;
	output.vTexCoord0 = input.vTexCoord0;
	
#ifdef MULTI_LAYER_BLENDING
	output.vTexCoord1 = input.vTexCoord1;
#endif

#if SOFT_PARTICLE == 1 || DISTORTION_MASKING == 1

	float4 vworldViewPos = mul( input.vPosition, g_matWorldView );
	
	output.vVPOS.z = -vworldViewPos.z;	
	output.vVPOS.xyw = ConvertToVPos( output.vPosition ).xyw;
#endif
	
	float fFogNear 			= g_vFogFactor.x;
//	float fFogEnd 			= g_vFogFactor.y;
	float fReciprocalfogDist= g_vFogFactor.z;
	float fFactor 			= g_vFogFactor.w;
	// 0:포그없음 1:포그가득
    output.fFog = saturate( ( output.vPosition.z - fFogNear ) * fReciprocalfogDist ) + fFactor;

	return output;
}

///////////////////////////////////////////////////////////////////////////////


float4 PSMAIN( 
	VSOUTPUT input 

) : COLOR
{
	float4 output = float4(0,0,0,0);

///////////////////////////////////////////////////////////////////////////////
// First Color
	float4 vDiffuseColor0 = tex2D( DiffuseMap, input.vTexCoord0 );
	vDiffuseColor0 *= input.vColor;

#ifdef SELF_ILLUMINATION
	float4 vSelfIlluminationColor0 = tex2D( IlluminationMap, input.vTexCoord0 );
	vSelfIlluminationColor0 *= g_vIlluminationScale;
	vDiffuseColor0.rgb += vSelfIlluminationColor0.rgb;
#endif


///////////////////////////////////////////////////////////////////////////////
// Second Color
#ifdef MULTI_LAYER_BLENDING
	float4 vDiffuseColor1 = tex2D( DiffuseMap, input.vTexCoord1.xy );
	vDiffuseColor1 *= input.vColor;
	
#ifdef SELF_ILLUMINATION
	float4 vSelfIlluminationColor1 = tex2D( IlluminationMap, input.vTexCoord1.xy );
	vSelfIlluminationColor1 *= g_vIlluminationScale;
	vDiffuseColor1.rgb += vSelfIlluminationColor1.rgb;
#endif

#endif


///////////////////////////////////////////////////////////////////////////////
// Final Color
#ifdef MULTI_LAYER_BLENDING
	float fBlend = input.vTexCoord1.z;
	float fBlendInverse = 1.f - fBlend;
	output = vDiffuseColor0 * fBlendInverse + vDiffuseColor1 * fBlend;
#else
	output = vDiffuseColor0;
#endif


///////////////////////////////////////////////////////////////////////////////
// Fog
	output.rgb = lerp( output.rgb, g_vFogColor, input.fFog );
	

///////////////////////////////////////////////////////////////////////////////
// Alpha Test
#ifdef ALPHA_TEST
	if( output.a <= g_fAlphaRef )
		discard;
#endif

#if SOFT_PARTICLE == 1 || DISTORTION_MASKING == 1
	float2 vScreenCoords = input.vVPOS.xy / input.vVPOS.w;
#endif

///////////////////////////////////////////////////////////////////////////////
// Soft Particle
#if SOFT_PARTICLE == 1 || DISTORTION_MASKING == 1
	float fPositionZ = input.vVPOS.z;

	// 샘플링 할 점의 깊이를 얻음. 
	float fDepthValue = tex2D( DepthBufferMap, vScreenCoords).r;
	// DepthBuffer에 저장된 값의 부호는 NormalBuffer에 저장된 normal의 Z축 부호를 나타내므로 부호를 없애준다.
	fDepthValue = abs( fDepthValue );
	float fScreenZ = fDepthValue * g_fFarZ;
	
	float fBlendFactor = saturate( ( ( fScreenZ - fPositionZ ) / g_fDepthBiasBlendDist ) - 0.2f );
	fBlendFactor = pow( fBlendFactor, 2 );
	
#ifdef SOFT_PARTICLE_BLEND_ALPHA
	output.a *= fBlendFactor;
#endif

#ifdef SOFT_PARTICLE_BLEND_COLOR
	output.rgb *= fBlendFactor;
#endif

#endif

///////////////////////////////////////////////////////////////////////////////
// Distortion Masking
#ifdef DISTORTION_MASKING

	float fAttenuationBegin = g_fAttenuationBegin;
	
	if( output.a <= 0  || fBlendFactor <= 0 )
	  discard;
	output.xy = GetDistortion(input.vTexCoord0) * min( output.a / fAttenuationBegin, 1 );
#endif
	
	return output;
}

float4 PSProfile( 
	VSOUTPUT input 
) : COLOR
{
	return float4(0.01f, 0,0,1);
}
///////////////////////////////////////////////////////////////////////////////

technique ParticleTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 VSMAIN();
		PixelShader  = compile ps_3_0 PSMAIN();
	}
}

technique ProfileTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 VSMAIN();
		PixelShader  = compile ps_3_0 PSProfile();
	}
}

///////////////////////////////////////////////////////////////////////////////