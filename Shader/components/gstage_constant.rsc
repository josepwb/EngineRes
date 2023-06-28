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
	// G-Stage에 기록 하는 것은 뷰 스페이스 기준 노말이다. 그러므로 WorldView와 곱한 노말을 출력으로 사용.
	float3 vWorldViewNormal = 0;
	IMPORT ( E_vWorldViewNormal, vWorldViewNormal = E_vWorldViewNormal);

	output.vNormal 		= vWorldViewNormal;
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	float3 vNormal = normalize(input.vNormal);
	EXPORT( float3, E_pgNormal, vNormal);
}
