interface()
{
	$name = multi_normalmap_blend
	$define = multi_normalmap_blend
	$dependency = texcoord
}

sampler ThirdNormalMap : register(s6);
sampler NormalMapMask3 : register(s8);

shared int g_iBlendTypeSec;
void PSMAIN( inout PSOUTPUT output)
{
	float4 vPrevColor = 0;
 	IMPORT( E_vNormalColor, vPrevColor = E_vNormalColor);

	float4 vLayer2Color = ReadLayerMap(6, ThirdNormalMap, 1 );
	float4 vLayer2Mask = ReadLayerMap(8, NormalMapMask3, 1);

	float4 vLayer0Mask = 1.f;
	IMPORT( E_vLayer0Mask, vLayer0Mask = E_vLayer0Mask );
	
	float4 vBlendedColor = GetBlendColor( vPrevColor, vLayer2Color * vLayer0Mask.b, g_iBlendTypeSec );
	
	EXPORT(float4, E_vNormalColor, vBlendedColor);
	EXPORT(float,  E_fNormalAlpha, vBlendedColor.a);
}