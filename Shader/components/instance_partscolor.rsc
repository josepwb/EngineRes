interface()
{
	$name = instance_partscolor
	$define = partscolor
	$dependency = instancing
}

struct VSOUTPUT
{
	float4 vPartsColor : TEXCOORD%;
};

void VSMAIN(inout VSOUTPUT output)
{
	float4 vinstanceClr;
	IMPORT( E_vInstancePartsColor, vinstanceClr = E_vInstancePartsColor);
	output.vPartsColor = vinstanceClr;	
}


void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	EXPORT(float4, E_vPartsColor, input.vPartsColor);
}

