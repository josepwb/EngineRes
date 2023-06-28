interface()
{
	$name = texcoord_normal_trans
	$dependency = texcoord
}

void PSMAIN(inout PSOUTPUT output)
{
	float2 vNormalTexcoord = 0;
	IMPORT( E_vNormalCoord, vNormalTexcoord = E_vNormalCoord);
	vNormalTexcoord = ApplyUVTransform(vNormalTexcoord, g_UVTransform[4]);

	EXPORT(float2, E_vNormalCoord, vNormalTexcoord);
}