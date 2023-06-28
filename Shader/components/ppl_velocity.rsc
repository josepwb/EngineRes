interface()
{
	$name = pplvblur
	$define = pplvblur
	$dependency = transform_vblur
}

struct VSOUTPUT
{
	float4 vVelocity	: TEXCOORD%;
};


void VSMAIN(inout VSOUTPUT output)
{
	float4 vWorldPosition = 0;
	IMPORT ( E_vWorldPosition, vWorldPosition = E_vWorldPosition);

	float4 vWorldPositionPrev = 0;
	IMPORT ( E_vWorldPositionPrev, vWorldPositionPrev = E_vWorldPositionPrev);

	
	float4 vPosProjSpaceCurrent = mul( vWorldPosition, g_matViewProj);
	vPosProjSpaceCurrent /= vPosProjSpaceCurrent.w;
	float4 vPosProjSpaceLast = mul( vWorldPositionPrev, g_matViewProj);
	vPosProjSpaceLast /= vPosProjSpaceLast.w;
	
	float vVelocityFactor = 1;
	IMPORT ( E_fVelocityFactor, vVelocityFactor = E_fVelocityFactor);
	
	output.vVelocity = vPosProjSpaceCurrent - vPosProjSpaceLast;
	output.vVelocity *= vVelocityFactor;
	output.vVelocity.x *= +0.5f;
	output.vVelocity.y *= -0.5f;
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	output.color = input.vVelocity;
}
