interface()
{
	$name = selfilluminationmap
	$define = selfilluminationmap
	$dependency = texcoord
}

sampler IlluminationMap : register(s5);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vSelfIlluminationCoord = 0;
	IMPORT( E_vSelfIlluminationCoord, vSelfIlluminationCoord = E_vSelfIlluminationCoord);
	float4 vSelfIlluminationColor = tex2D( IlluminationMap, vSelfIlluminationCoord);
	
	g_vSavedAlpha[REFLECT_SI] = vSelfIlluminationColor.a;
	g_fReflect[REFLECT_SI] = vSelfIlluminationColor.a;
	g_fFakeSSSMask[REFLECT_SI] = vSelfIlluminationColor.a;

	EXPORT(float4, E_vSelfilluminationColor, vSelfIlluminationColor);
	EXPORT(float,  E_fSelfilluminationAlpha, vSelfIlluminationColor.a);
}