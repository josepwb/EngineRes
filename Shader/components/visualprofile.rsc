interface()
{
	$name = visualprofile
}

shared float4 g_fProfileValue;

void PSMAIN(inout PSOUTPUT output)
{
	output.color = g_fProfileValue;
}