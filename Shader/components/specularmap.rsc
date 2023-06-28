interface()
{
	$name = specularmap
	$define = specularmap
	$dependency = texcoord
}

sampler SpecularMap : register(s6);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vSpecularCoord = 0;
	IMPORT( E_vSpecularCoord, vSpecularCoord = E_vSpecularCoord);

	float4 vSpec   = tex2D( SpecularMap, vSpecularCoord );
	
	g_vSavedAlpha[ REFLECT_SPECULAR ] = vSpec.a;
	g_fReflect[ REFLECT_SPECULAR ] = vSpec.r;
	g_fFakeSSSMask[ REFLECT_SPECULAR ] = vSpec.a;

	EXPORT(float3, E_vSpecularColor, vSpec.rgb);
	EXPORT(float, E_fSpecularAlpha, vSpec.a);
}