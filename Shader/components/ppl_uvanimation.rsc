interface()
{
	$name = ppl_uvanimation
	$define = ppl_uvanimation
}

shared float4 g_UVAnimation;

void PSMAIN(inout PSOUTPUT output)
{
	float2 vTexcoord =0;
	IMPORT(E_vTexcoord, vTexcoord = E_vTexcoord);

	EXPORT(float2, E_vTexcoord, ApplyUVTransform(vTexcoord, g_UVAnimation));
}