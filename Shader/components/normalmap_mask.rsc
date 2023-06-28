interface()
{
	$name	= normalmap_mask
	$define	= normalmap_mask
	$dependency = texcoord
}

sampler NormalMapMask1 : register(s7);

void PSMAIN( inout PSOUTPUT output)
{
	float4 vLayer0Mask = ReadLayerMap( 7, NormalMapMask1, 1 );
	EXPORT(float4, E_vLayer0Mask, vLayer0Mask);
}