interface()
{
	$name = dual_specularmap_colorburn
	$define = specularmap
	$dependency = texcoord
}

sampler SpecularMap : register(s6);
sampler SecondSpecularMap : register(s15);

shared float2 g_fSpecularLayerOpacity;

void PSMAIN( inout PSOUTPUT output)
{
	//-------------------------------------------------------------
	//Calculate Texture coord
	float4 vUV =0;
	IMPORT( E_vSpecularCoord, vUV.xy = E_vSpecularCoord);
	IMPORT( E_vTexCoord2, vUV.zw = E_vTexCoord2);

	float2 vTexcoord0 = GetTexcoordResult(vUV, 6);
	float2 vTexcoord1 = GetTexcoordResult(vUV, 15);
	//-------------------------------------------------------------


	//Read SpecularMap Map
	float4 vSpecularColor0 = tex2D( SpecularMap, vTexcoord0) *g_fSpecularLayerOpacity.x;
	float4 vSpecularColor1 = tex2D( SecondSpecularMap, vTexcoord1);


	//Apply 'Color Burn' Blend Mode
	float4 vBlendedColor =  max( 1.0f - (1.0f - vSpecularColor0) / (vSpecularColor1+0.0001f), 0.0f );
	

	//Apply Layer Opacity
	float4 vSpecularColor =  lerp(vSpecularColor0, vBlendedColor, g_fSpecularLayerOpacity.y);


	g_vSavedAlpha[ REFLECT_SPECULAR ] = vSpecularColor.a;
	g_fReflect[ REFLECT_SPECULAR ] = vSpecularColor.r;
	g_fFakeSSSMask[ REFLECT_SPECULAR ] = vSpecularColor.a;

	EXPORT(float3, E_vSpecularColor, vSpecularColor.rgb);
	EXPORT(float, E_fSpecularAlpha, vSpecularColor.a);
}