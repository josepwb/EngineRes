interface()
{
	$name = texcoord_world
	$define = texcoord_export
	$dependency = transform
}

shared matrix  	g_textureTransform;

struct VSOUTPUT
{
	float2 vTexcoord	: TEXCOORD%;
};

void VSMAIN(out VSOUTPUT output)
{
	float4 vWorldPosition = 0;
	IMPORT ( E_vWorldPosition, vWorldPosition = E_vWorldPosition);

	output.vTexcoord = mul(vWorldPosition ,g_textureTransform).xy;
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	EXPORT(float2, E_vTexcoord, input.vTexcoord);
}