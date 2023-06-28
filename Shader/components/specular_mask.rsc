interface()
{
	$name = specular_mask
	$define = specular_mask
	$dependency = texcoord
}

sampler SpecularMaskMap : register(s10);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vDiffuseCoord = 0;
	IMPORT( E_vDiffuseCoord, vDiffuseCoord = E_vDiffuseCoord);
	float4 vSpecularMaskColor = tex2D( SpecularMaskMap, vDiffuseCoord);
		
	EXPORT(float4, E_vSpecularMaskColor, vSpecularMaskColor);
}