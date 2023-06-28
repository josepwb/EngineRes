interface()
{
	$name = transform_constant
	$define = transform_constant
}

shared matrix	g_matWorld;
shared matrix	g_matWorldView;
shared matrix	g_matWorldViewProj;
shared matrix	g_matView;
shared matrix	g_matProj;
shared matrix	g_matViewProj;
shared matrix	g_mViewInv;
shared float3	g_vEyePosition;
shared float3	g_vLightVec;
shared float4	g_vLightDiffuse;