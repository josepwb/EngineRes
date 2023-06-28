interface()
{
	$name = dual_normalmap
	$define = normalmap
	$dependency = texcoord
}
#include "BlendColor_h.fx"

sampler NormalMap : register(s4);
sampler SecondNormalMap : register(s14);


shared float2 g_fNormalLayerOpacity;
shared int g_iBlendType;

void PSMAIN( inout PSOUTPUT output)
{
	//-------------------------------------------------------------
	//Calculate Texture coord
	float4 vUV = 0;
	IMPORT( E_vNormalCoord,	vUV.xy = E_vNormalCoord);
	IMPORT( E_vTexCoord2,		vUV.zw = E_vTexCoord2);

	float2 vTexcoord0 = GetTexcoordResult( vUV, 4 );
	float2 vTexcoord1 = GetTexcoordResult( vUV, 14 );
	//-------------------------------------------------------------

	float4 vNormalColor0 = tex2D( NormalMap, vTexcoord0 ) * g_fNormalLayerOpacity.x;
	float4 vNormalColor1 = tex2D( SecondNormalMap, vTexcoord1 );
	
	// 마스크 인덱스 고려. 마스크값 구하는 공식 따로 만듬
	float4 vLayer0Mask = 1.f;
	IMPORT( E_vLayer0Mask, vLayer0Mask = E_vLayer0Mask );
	
	float4 vBlendedColor = GetBlendColor( vNormalColor1 * vLayer0Mask.g, vNormalColor0 * vLayer0Mask.r, g_iBlendType );
	
	float4 vNormalColor =  lerp(vNormalColor0, vBlendedColor, g_fNormalLayerOpacity.y);	

	g_vSavedAlpha[REFLECT_NORMAL]		= vNormalColor.a;
	g_fReflect[REFLECT_NORMAL]				= vNormalColor.a;
	g_fFakeSSSMask[ REFLECT_NORMAL ]	= vNormalColor.a;

	EXPORT(float4, E_vNormalColor, vNormalColor);
	EXPORT(float,  E_fNormalAlpha, vNormalColor.a);
}