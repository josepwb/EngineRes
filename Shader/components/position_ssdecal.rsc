interface()
{
	$name = position_decal
	$define = position
}

struct VSINPUT
{
	float4 vPosition	: POSITION;

	float4 matWorld0	: NORMAL0;
	float4 matWorld1	: NORMAL1;
	float4 matWorld2	: NORMAL2;
	float4 matWorld3	: NORMAL3;

	float4 matViewToDecal0	: TEXCOORD0;
	float4 matViewToDecal1	: TEXCOORD1;
	float4 matViewToDecal2	: TEXCOORD2;
	float4 matViewToDecal3	: TEXCOORD3;

	float3 vLocalPosition : TEXCOORD4;
	float4 vLocalRange : TEXCOORD5;
};

struct VSOUTPUT
{
	float4 matViewToDecal0	: TEXCOORD%;
	float4 matViewToDecal1	: TEXCOORD%;
	float4 matViewToDecal2	: TEXCOORD%;
	float4 matViewToDecal3	: TEXCOORD%;
	float fVisibility : TEXCOORD%;
};

void VSMAIN(VSINPUT input, out VSOUTPUT output)
{
	float4 vLocalPosition = 1;
	vLocalPosition.xyz = input.vPosition.xyz*input.vLocalRange.xyz + input.vLocalPosition;
	EXPORT(float4, E_vLocalPosition, vLocalPosition);


	float4x4 matWorld = {input.matWorld0, input.matWorld1, input.matWorld2, input.matWorld3};
	g_matWorld = matWorld;
	g_matWorldView		= mul( matWorld, g_matView );
	g_matWorldViewProj	= mul( matWorld, g_matViewProj );


	output.matViewToDecal0 = input.matViewToDecal0;
	output.matViewToDecal1 = input.matViewToDecal1;
	output.matViewToDecal2 = input.matViewToDecal2;
	output.matViewToDecal3 = input.matViewToDecal3;
	output.fVisibility = input.vLocalRange.w;
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	float4x4 matViewToDecal = {input.matViewToDecal0, input.matViewToDecal1, input.matViewToDecal2, input.matViewToDecal3};
	EXPORT(float4x4, E_matViewToDecal, matViewToDecal);

	EXPORT(float, E_fVisibility, input.fVisibility);
}