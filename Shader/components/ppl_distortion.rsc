interface()
{
	$name = ppldistortion
	$define = ppldistortion
}

#include "DistortionMask_h.fx"
sampler DepthMap : register(s8);

struct VSOUTPUT
{
	float4 vVPOS	: TEXCOORD%;
};

shared float2 g_vInverseViewportDimensions;

float4 ConvertToVPos( float4 p )
{
   return float4( 0.5*( float2(p.x + p.w, p.w - p.y) + p.w*g_vInverseViewportDimensions.xy ), p.zw);
}

void VSMAIN(out VSOUTPUT output)
{	
	float4 vWVP = 0;
	IMPORT(E_vWorldViewPosition, vWVP = E_vWorldViewPosition);
	output.vVPOS.z	= -vWVP.z;
	
	IMPORT(E_vWVP, vWVP = E_vWVP);
	output.vVPOS.xyw = ConvertToVPos(vWVP).xyw;
}


void PSMAIN( in VSOUTPUT input, inout PSOUTPUT output)
{

	float2 vDiffuseCoord = 0;
	IMPORT( E_vDiffuseCoord, vDiffuseCoord = E_vDiffuseCoord);
	
	float2 vScreenCoords = input.vVPOS.xy/ input.vVPOS.w;
	
	float fPositionZ = input.vVPOS.z;

	float fDepthValue = tex2D( DepthMap, vScreenCoords).r;
	fDepthValue = abs( fDepthValue );
	float fScreenZ = fDepthValue * g_fDistortionFarZ;
	
	float fBlendFactor = fScreenZ - fPositionZ;

	if( fBlendFactor <= 0 )
	  discard;


	float2 vDistortion = GetDistortion( vDiffuseCoord);
	
	output.color.rgb = float3( vDistortion, 1);
}