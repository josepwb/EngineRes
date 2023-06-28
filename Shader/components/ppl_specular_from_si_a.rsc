interface()
{
	$name = ppl_specular_si_alpha
	$dependency = selfilluminationmap
}

void PSMAIN( inout PSOUTPUT output)
{
	float3 vPixelSpecular = 1;
	IMPORT( E_vPixelSpecular, vPixelSpecular = E_vPixelSpecular);

	float fSelfIlluminationAlpha = 0;
	IMPORT( E_fSelfilluminationAlpha, fSelfIlluminationAlpha = E_fSelfilluminationAlpha);

	float3 vSpecular = vPixelSpecular * fSelfIlluminationAlpha;
	EXPORT( float3,  E_vLitSpecular, vSpecular);
}
