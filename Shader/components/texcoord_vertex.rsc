interface()
{
	$name = texcoord_vertex
	$define = texcoord_export
}

struct VSINPUT
{
	float2 vTexcoord	: TEXCOORD0;
};

struct VSOUTPUT
{
	float2 vTexcoord	: TEXCOORD%;
};

void VSMAIN(VSINPUT input, out VSOUTPUT output)
{
	output.vTexcoord = input.vTexcoord;
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	EXPORT(float2, E_vTexcoord, input.vTexcoord);
}