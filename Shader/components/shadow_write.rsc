interface()
{
	$name = shadow_write
	$define = transform
	$dependency = position
}

struct VSOUTPUT
{
	float4 vPosition	: POSITION;
};

void VSMAIN(inout VSOUTPUT output)
{
	float4 vLocalPosition = 0;
	IMPORT ( E_vLocalPosition, vLocalPosition = E_vLocalPosition);

	output.vPosition = mul(vLocalPosition, g_matWorldViewProj);
}


shared float g_fShadowValue;
	
void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	output.color = g_fShadowValue;
}