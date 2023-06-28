float GetFogTerm( float fPositionZ, float4 vFogFactor )
{
	float fogNear = vFogFactor.x;
    float fogEnd = vFogFactor.y;
    float reciprocalfogDist = vFogFactor.z;
    float fFactor = vFogFactor.w;

	// 0:���׾��� 1:���װ���
    return saturate( (fPositionZ - fogNear)*reciprocalfogDist) + fFactor;
}

float2 ApplyUVTransform( float2 uv, float4 vTransform )
{
	return uv *vTransform.zw +vTransform.xy;
}