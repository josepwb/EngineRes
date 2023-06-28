interface()
{
	$name 		= ppl_self_illumination
	$dependency = selfilluminationmap
}

shared float3 g_vIlluminationScale;

void PSMAIN(inout PSOUTPUT output)
{
	float4 vIlluminationColor;
	IMPORT( E_vSelfilluminationColor, vIlluminationColor = E_vSelfilluminationColor);
	
	vIlluminationColor.rgb *= g_vIlluminationScale;
	EXPORT( float3, E_vAddColor, vIlluminationColor.rgb);
}
