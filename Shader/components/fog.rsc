interface()
{
	$name = fog
	$define = fog
	$dependency = transform
}

struct VSOUTPUT
{
	float  fFog		: TEXCOORD%;
};

shared float4		g_vFogFactor;   // x : near, y : far, z : dist , w : factor (multiply)
shared float3		g_vFogColor;

void VSMAIN(inout VSOUTPUT output)
{
	float fPositionZ = 0;
	IMPORT( E_vPositionZ, fPositionZ = E_vPositionZ);

	output.fFog = GetFogTerm( fPositionZ, g_vFogFactor );
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	output.color.rgb  = lerp( output.color.rgb, g_vFogColor, input.fFog);
}