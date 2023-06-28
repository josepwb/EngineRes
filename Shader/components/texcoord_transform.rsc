interface()
{
	$name = texcoord_transform
	$define = texcoord_export
}

struct VSINPUT
{
	float2 vDiffuseCoord	: TEXCOORD0;
};

struct VSOUTPUT
{
	float2 vTexcoord	: TEXCOORD%;
};

shared float4 g_UVAnimation;

void VSMAIN(VSINPUT input, out VSOUTPUT output)
{
	output.vTexcoord = ApplyUVTransform(input.vDiffuseCoord, g_UVAnimation);
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	EXPORT(float2, E_vTexcoord, input.vTexcoord);
}