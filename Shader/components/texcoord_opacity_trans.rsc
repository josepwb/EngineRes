interface()
{
	$name = texcoord_opacity_trans
	$dependency = texcoord
}

void PSMAIN(inout PSOUTPUT output)
{
	float2 vOpacityCoord = 0;
	IMPORT( E_vOpacityCoord, vOpacityCoord = E_vOpacityCoord);
	vOpacityCoord = ApplyUVTransform(vOpacityCoord, g_UVTransform[7]);

	EXPORT(float2, E_vOpacityCoord, vOpacityCoord);
}