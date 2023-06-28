interface()
{
	$name 		= ppl_diffuse
	$define		= ppl_diffuse
	$dependency = diffusemap
}

void PSMAIN(inout PSOUTPUT output)
{
	float4 vDiffuseColor;
	IMPORT( E_vDiffuseColor, vDiffuseColor = E_vDiffuseColor);
	
	output.color = vDiffuseColor;
	output.color.a = 1;
}
