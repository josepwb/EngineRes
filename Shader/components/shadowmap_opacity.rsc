interface()
{
	$name = shadowmap_alpha
	$define = shadowmap_alpha
}

sampler DiffuseMap : register(s0);
shared int g_nShadowMapOpacityIndex = 3;
	
void PSMAIN(inout PSOUTPUT output)
{
	float4 vUV =0;
	IMPORT( E_vOpacityCoord, vUV.xy = E_vOpacityCoord);
	IMPORT( E_vTexCoord2, vUV.zw = E_vTexCoord2);

	float2 vTexcoord = GetTexcoordResult(vUV, 0);

	output.color.a = tex2D( DiffuseMap, vTexcoord )[g_nShadowMapOpacityIndex];
}
