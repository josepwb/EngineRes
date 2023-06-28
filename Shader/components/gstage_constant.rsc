interface()
{
	$name = g_constant
	$define = g_constant
}

struct VSOUTPUT
{
	float3 vNormal		: TEXCOORD%;
};

void VSMAIN(inout VSOUTPUT output)
{
	// G-Stage�� ��� �ϴ� ���� �� �����̽� ���� �븻�̴�. �׷��Ƿ� WorldView�� ���� �븻�� ������� ���.
	float3 vWorldViewNormal = 0;
	IMPORT ( E_vWorldViewNormal, vWorldViewNormal = E_vWorldViewNormal);

	output.vNormal 		= vWorldViewNormal;
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	float3 vNormal = normalize(input.vNormal);
	EXPORT( float3, E_pgNormal, vNormal);
}
