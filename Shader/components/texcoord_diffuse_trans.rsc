interface()
{
	$name = texcoord_diffuse_trans
	$dependency = texcoord
}

void PSMAIN(inout PSOUTPUT output)
{
	float2 vDiffuseTexcoord =0;
	IMPORT( E_vDiffuseCoord, vDiffuseTexcoord = E_vDiffuseCoord);
	vDiffuseTexcoord = ApplyUVTransform(vDiffuseTexcoord, g_UVTransform[0]);

	EXPORT(float2, E_vDiffuseCoord, vDiffuseTexcoord);
}