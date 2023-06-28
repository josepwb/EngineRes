interface()
{
	$name = diffusemap_partscolor_constant
	$define = partscolor
}

shared float4	g_vPartsColor;

void PSMAIN(inout PSOUTPUT output)
{
	EXPORT(float4, E_vPartsColor, g_vPartsColor);
}