interface()
{
	$name = specular_shift
	$define = specular_shift
	$dependency = texcoord
}

sampler SpecularShiftMap : register(s11);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vDiffuseCoord = 0;
	IMPORT( E_vDiffuseCoord, vDiffuseCoord = E_vDiffuseCoord);
	float4 vSpecularShiftColor = tex2D( SpecularShiftMap, vDiffuseCoord  );
		
	EXPORT(float4, E_vSpecularShiftColor, vSpecularShiftColor);
}