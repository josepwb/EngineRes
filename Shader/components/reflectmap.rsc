interface()
{
	$name		= reflect_map
	$define 	= reflect_map
	$dependency	= texcoord
}

sampler sEnv_Map : register(s5);

shared int g_iUseEnvAlpha;
shared int g_iUseEnvMask ;


float fresnel(float3 eyevec, float3 normal, float power, float bias)
{
	normal = normalize(normal);
	eyevec = normalize(eyevec);
	
	float fresnel = saturate(abs(dot(normal,eyevec))); // �븻�� �� ���͸� ���� �𼭸� ���Ѵ�.
	//fresnel = 1 - fresnel; 								// �𼭸� ���� ���� �����ϴ�.
	fresnel = pow(fresnel, power);						// �𼭸� �κ��� ��ī�ο����� ����.
	fresnel += bias; 									// ��������� ������ ������ΰ�.
	
	return saturate(fresnel);
}

struct VSOUTPUT
{
	float4 vWorld_Position	: TEXCOORD%;
	float3 vViewWorld		: TEXCOORD%;
};


void VSMAIN(out VSOUTPUT output)
{	
	float4 vWorldPosition = 0;
	IMPORT(E_vWorldPosition, vWorldPosition = E_vWorldPosition);
	output.vWorld_Position = vWorldPosition;

	output.vViewWorld = vWorldPosition - g_vEyePosition;
}

void PSMAIN(in VSOUTPUT input, inout PSOUTPUT output )
{	
	float3 vViewNormal = 0;
	IMPORT(E_pgNormal, vViewNormal = E_pgNormal );	
	float3 vWorldNormal = mul(vViewNormal, (float3x3)g_mViewInv).xyz;
		
	float3 I = input.vViewWorld;		// �� ���������� ���� ��ġ
	float3 R = reflect( I, vWorldNormal );
	
	R.yz = R.zy;
	
	float fGlossiness = g_vSavedAlpha[ g_iUseEnvAlpha ];
	float4 vEnvironmentColor = texCUBElod( sEnv_Map, float4(R, 6.01329f - (fGlossiness * 6.01329f)));	

	float fFresnel = fresnel( I, vViewNormal, 2.26f, 0.55f);	// 4���� ����. ���� ���� ������ ����, ���� ���� �а� ���´�.
	
	float fFr = g_fReflect[ g_iUseEnvMask ] * fFresnel;
	fFr = saturate( fFr);
	
	output.color.rgb = lerp( output.color.rgb, vEnvironmentColor.rgb, fFr );
	
}
