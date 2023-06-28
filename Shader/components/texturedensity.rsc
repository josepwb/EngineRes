interface()
{
	$name = textuerdensity
	$dependency = texcoord
}

shared float g_DiffuseTextureSize;
shared float g_fAreaPerPixel = 5.0f;

struct VSOUTPUT
{
	float3 vWorldPosition	: TEXCOORD%;
};

void VSMAIN(inout VSOUTPUT output)
{
	float4 vWorldPosition =0;
	IMPORT(E_vWorldPosition , vWorldPosition = E_vWorldPosition);

	output.vWorldPosition = vWorldPosition.xyz;
}

void PSMAIN(in VSOUTPUT input, inout PSOUTPUT output)
{
	float2 vDiffuseCoord = 0;
	IMPORT( E_vDiffuseCoord, vDiffuseCoord = E_vDiffuseCoord);

	float2 dTexdX = ddx(vDiffuseCoord);
	float2 dTexdY = ddy(vDiffuseCoord);

	float AreadTex = length(cross(float3(dTexdX,0),float3(dTexdY,0)));


	float3 dPdX = ddx(input.vWorldPosition);
	float3 dPdY = ddy(input.vWorldPosition);

	float AreadP = length(cross(dPdX,dPdY));

	float fResult = AreadTex/AreadP * (g_DiffuseTextureSize/(g_fAreaPerPixel*g_fAreaPerPixel));

	float4 vLowColor = float4(0,1,0,1);
	float4 vMiddleColor = float4(0,0,1,1);
	float4 vHighColor = float4(1,0,0,1);
	
	if(fResult<0.5f)
		output.color = lerp(vLowColor, vMiddleColor, fResult/0.5f);
	else
		output.color = lerp(vMiddleColor, vHighColor, (fResult-0.5f)/0.5f);
}