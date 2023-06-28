interface()
{
	$name = depth
	$define = transform
	$dependency = position
}

struct VSOUTPUT
{
	float4 vPosition	: POSITION;
	float3 vPos : TEXCOORD%;
};

void VSMAIN( inout VSOUTPUT output)
{
	float4 vLocalPosition = 0;
	IMPORT ( E_vLocalPosition, vLocalPosition = E_vLocalPosition);

	output.vPosition = mul(vLocalPosition, g_matWorldViewProj);
	output.vPos = mul(vLocalPosition, g_matWorldView).xyz;
}
	
void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	output.color = input.vPos.z;
}