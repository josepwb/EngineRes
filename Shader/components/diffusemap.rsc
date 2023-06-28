interface()
{
	$name = diffusemap
	$define = diffusemap
	$dependency = texcoord
}

sampler DiffuseMap : register(s0);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vDiffuseCoord = 0;
	IMPORT( E_vDiffuseCoord, vDiffuseCoord = E_vDiffuseCoord);
	float4 vDiffuseColor = tex2D( DiffuseMap, vDiffuseCoord);
	
	g_vSavedAlpha[ REFLECT_DIFFUSE ] = vDiffuseColor.a;
	g_fReflect[ REFLECT_DIFFUSE ] = vDiffuseColor.a;
	g_fFakeSSSMask[ REFLECT_DIFFUSE ] = vDiffuseColor.a;
	
	EXPORT(float4, E_vDiffuseColor, vDiffuseColor);
	EXPORT(float,  E_fDiffuseAlpha, vDiffuseColor.a);
}
