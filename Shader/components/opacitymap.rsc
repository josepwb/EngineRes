interface()
{
	$name = opacitymap
	$define = opacitymap
	$dependency = texcoord
}

sampler OpacityMap : register(s7);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vOpacityCoord = 0;
	IMPORT( E_vOpacityCoord, vOpacityCoord = E_vOpacityCoord);

	float fOpacity = tex2D( OpacityMap, vOpacityCoord ).r;
	
	g_vSavedAlpha[REFLECT_OPACITY] = fOpacity;
	g_fReflect[REFLECT_OPACITY] = fOpacity;
	g_fFakeSSSMask[REFLECT_OPACITY] = fOpacity;

	EXPORT(float, E_fOpacityAlpha, fOpacity);
}