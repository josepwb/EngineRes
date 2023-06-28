interface()
{
	$name = ppl_cos_view
	$define = ppl_cos_view
	$dependency = transform
}

struct VSOUTPUT
{
	float3 vNormal		: TEXCOORD%;
	float3 vViewDir		: TEXCOORD%;
};

void VSMAIN(inout VSOUTPUT output)
{
	float3 vWorldNormal = 0;
	IMPORT ( E_vWorldNormal, vWorldNormal = E_vWorldNormal);
	output.vNormal 		= vWorldNormal;


	float4 vWorldPosition = 0;
	IMPORT(E_vWorldPosition, vWorldPosition = E_vWorldPosition);

	float3 vEyePos = 0;
	IMPORT(E_vEyePosition, vEyePos = E_vEyePosition);

	output.vViewDir = vEyePos.xyz - vWorldPosition.xyz;
}


void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	float3 vNormal = normalize(input.vNormal);
	float3 vViewDir = normalize(input.vViewDir);
	float cosView = abs( dot( vViewDir, vNormal ) );

	EXPORT( float3, E_pplNormal, vNormal);
	EXPORT( float, E_fCosView, cosView );
}

