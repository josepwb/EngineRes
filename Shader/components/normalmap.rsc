interface()
{
	$name = normalmap
	$define = normalmap
	$dependency = texcoord
}

sampler NormalMap : register(s4);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vNormalCoord = 0;
	IMPORT( E_vNormalCoord, vNormalCoord = E_vNormalCoord);
	float4 vNormalColor = tex2D( NormalMap, vNormalCoord);
	
	g_vSavedAlpha[REFLECT_NORMAL] = vNormalColor.a;
	g_fReflect[REFLECT_NORMAL] = vNormalColor.a;
	g_fFakeSSSMask[REFLECT_NORMAL] = vNormalColor.a;

	EXPORT(float4, E_vNormalColor, vNormalColor);
	EXPORT(float,  E_fNormalAlpha, vNormalColor.a);
}