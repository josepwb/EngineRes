interface()
{
	$name = independentReflect
	$define = independentReflect
	$dependency = texcoord
}

sampler IndependentReflectMap : register(s12);

void PSMAIN( inout PSOUTPUT output)
{
	float2 vReflectionMaskCoord = 0;
	IMPORT(E_vReflectMaskCoord, vReflectionMaskCoord = E_vReflectMaskCoord);
	
	float4 vTexColor = tex2D( IndependentReflectMap, vReflectionMaskCoord);
	g_fReflect[ REFLECT_REFLECT ] = vTexColor.a;
}