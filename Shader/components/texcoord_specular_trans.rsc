interface()
{
	$name = texcoord_specular_trans
	$dependency = texcoord
}

void PSMAIN(inout PSOUTPUT output)
{
	float2 vSpecularCoord = 0;
	IMPORT( E_vSpecularCoord, vSpecularCoord = E_vSpecularCoord);
	vSpecularCoord = ApplyUVTransform(vSpecularCoord, g_UVTransform[6]);

	EXPORT(float2, E_vSpecularCoord, vSpecularCoord);
}