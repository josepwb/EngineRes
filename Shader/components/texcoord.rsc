interface()
{
	$name = texcoord
	$define = texcoord
	$dependency = texcoord_export
}

shared float4	g_UVTransform[16];
shared int		g_MapChannel[16];
shared float	g_vSavedAlpha[13]		= { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
shared float	g_fReflect[13]			= { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
shared float	g_fFakeSSSMask[13]		= { 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

#define		REFLECT_DIFFUSE		1
#define		REFLECT_NORMAL		2
#define		REFLECT_SI					3
#define		REFLECT_SPECULAR		7
#define		REFLECT_OPACITY		9
#define		REFLECT_REFLECT		12



float2 GetTexcoordResult(in float4 vUV, in int nSampler)
{
	//vUV.xy => Mapchannel :0, vUV.zw => Mapchannel :1

	float2 vTexcoord = 0;
	if(g_MapChannel[nSampler]==0)
		vTexcoord = vUV.xy;
	else
		vTexcoord = vUV.zw;

	vTexcoord = vTexcoord *g_UVTransform[nSampler].zw +g_UVTransform[nSampler].xy;

	return vTexcoord;
}

void PSMAIN(inout PSOUTPUT output)
{
	float2 vTexcoord =0;
	IMPORT(E_vTexcoord, vTexcoord = E_vTexcoord);

	EXPORT(float2, E_vReflectMaskCoord, vTexcoord);
	EXPORT(float2, E_vDiffuseCoord, vTexcoord);
	EXPORT(float2, E_vOpacityCoord, vTexcoord);
	EXPORT(float2, E_vNormalCoord, vTexcoord);
	EXPORT(float2, E_vSpecularCoord, vTexcoord);
	EXPORT(float2, E_vSelfIlluminationCoord, vTexcoord);	
	EXPORT(float2, E_vRenderTargetCoord, vTexcoord);
}