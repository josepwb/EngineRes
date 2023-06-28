interface()
{
	$name = texcoord_si_trans
	$dependency = texcoord
}

void PSMAIN(inout PSOUTPUT output)
{
	float2 vSelfIlluminationCoord = 0;
	IMPORT( E_vSelfIlluminationCoord, vSelfIlluminationCoord = E_vSelfIlluminationCoord);
	vSelfIlluminationCoord = ApplyUVTransform(vSelfIlluminationCoord, g_UVTransform[5]);

	EXPORT(float2, E_vSelfIlluminationCoord, vSelfIlluminationCoord);
}