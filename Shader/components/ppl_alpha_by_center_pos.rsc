interface()
{
	$name = ppl_alpha_by_center_pos
	$define = ppl_alpha_by_center_pos
	$dependency = transform
}

struct VSOUTPUT
{
	float4 vWorldPosCoord	: TEXCOORD%;
};

shared float3  g_vCenterPositionForAlpha;

void VSMAIN(inout VSOUTPUT output)
{
	output.vWorldPosCoord = 0;
	IMPORT ( E_vWorldPosition, output.vWorldPosCoord = E_vWorldPosition);
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	float3 distVec = g_vCenterPositionForAlpha - input.vWorldPosCoord.xyz;
	float dist = length(distVec);
	
	float limit = 300.f;
	if( limit < dist )
		discard;
		
	float visiblityRate = min((limit-dist)/limit*2.f, 1.f);
	
	output.color.a = output.color.a * visiblityRate;
}


