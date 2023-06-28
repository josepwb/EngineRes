interface()
{
	$name = fog_pixel
	$define = fog
	$dependency = transform
}

shared float4		g_vFogFactor;   // x : near, y : far, z : dist , w : factor (multiply)
shared float3		g_vFogColor;

void PSMAIN(inout PSOUTPUT output)
{
	float fPositionZ = 0;
	IMPORT( E_vPositionZ, fPositionZ = E_vPositionZ);

	output.color.rgb  = lerp( output.color.rgb, g_vFogColor, GetFogTerm(fPositionZ, g_vFogFactor) );
}