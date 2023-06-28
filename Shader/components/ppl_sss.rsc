interface()
{
	$name = ppl_sss
	$define = ppl_sss
}

shared float4	g_SubColor  = {1.0f, 0.2f, 0.2f, 1.0f};
shared float		g_RollOff = 0.4f;
shared float		g_fPowerSSS = 1.f;
shared float		g_f_M_G_BlendingValue = 0.45f;

shared int		g_iUseFakeSSSMask = 0;

float4 GetSubsurfaceLite(float DiffuseIntensity)
{
        float subLamb = smoothstep(-g_RollOff, 1.0f, DiffuseIntensity) - smoothstep(0.0f, 1.0f, DiffuseIntensity);
        subLamb = max( 0.f, subLamb );
        return subLamb * g_SubColor;
}


float HalfLambert( float3 Normal, float3 LightDir, float E )
{
	return pow( (0.5f * dot(Normal, LightDir)) + 0.5f, E );
}


void PSMAIN(inout PSOUTPUT output)
{	

	float fFakeSSSMask = g_fFakeSSSMask[ g_iUseFakeSSSMask ];
		
	float3 vFinalSSS = 0;
	
	float4 Output = float4(1, 1, 1, 1);
	float3 vViewNormal = 0;
	IMPORT(E_pgNormal, vViewNormal = E_pgNormal );
	
	float4 SSSdiffuse = 0;
	float3 lightVecT = g_vLightVec;

	float diffuseIntensity = HalfLambert( vViewNormal, lightVecT, g_fPowerSSS );
	SSSdiffuse = (diffuseIntensity);
	
	float4 subsurface = GetSubsurfaceLite( diffuseIntensity );
    SSSdiffuse += subsurface;		
	vFinalSSS = Output.rgb * SSSdiffuse.rgb;

	vFinalSSS *= g_f_M_G_BlendingValue * fFakeSSSMask;
	
	EXPORT( float3, E_vAddColor, vFinalSSS);
	
}
