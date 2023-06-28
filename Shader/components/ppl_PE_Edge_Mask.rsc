interface()
{
	$name = ppl_Edge_Mask
}

shared float3 g_vPEEdgeColor;

void PSMAIN(inout PSOUTPUT output)
{
	output.color.rgb = g_vPEEdgeColor;
}
