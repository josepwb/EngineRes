interface()
{
	$name = ppl_visiblity
	$define = ppl_visiblity
}

void PSMAIN(inout PSOUTPUT output)
{
	float fVisibility = 1.0f;
	IMPORT( E_fVisibility, fVisibility = E_fVisibility );
	output.color.a = output.color.a * fVisibility;
}