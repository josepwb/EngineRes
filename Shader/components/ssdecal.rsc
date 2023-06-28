interface()
{
	$name = ssdecal
	$define = texcoord_export
	$dependency = position
}

sampler GBufferDepthMap : register(s8);
sampler GBufferDiffuse: register(s9);



shared float3 g_vFarClipCornerInView;

float4 ReconstructPosFromDepth(float2 vScreencood, float fDepth)
{
	float3 vRay;
	vRay.xy = lerp(-g_vFarClipCornerInView.xy, g_vFarClipCornerInView.xy, vScreencood);
	vRay.z = g_vFarClipCornerInView.z;
	return float4(vRay*fDepth, 1);
}

void PSMAIN( inout PSOUTPUT output)
{
	float2 vBufferCoord = 0;
	IMPORT( E_vBufferCoord, vBufferCoord = E_vBufferCoord.xy/E_vBufferCoord.w);

	float fDepth = abs( tex2D(GBufferDepthMap, vBufferCoord).x );
	float4 vPosition = ReconstructPosFromDepth(vBufferCoord, fDepth);


	float4x4 matViewToDecal = 0;
	IMPORT( E_matViewToDecal, matViewToDecal = E_matViewToDecal);


	//GBuffer_Diffuse.rgb
	float4 vProjcoord = mul(vPosition, matViewToDecal);
	if( vProjcoord.x<0 || 1<vProjcoord.x ||
		vProjcoord.y<0 || 1<vProjcoord.y ||
		vProjcoord.z<0 || 1<vProjcoord.z )
		discard;

	EXPORT(float2, E_vTexcoord, vProjcoord.xy);


	//GBuffer_Diffuse.a
	float fAOMask = tex2D(GBufferDiffuse, vBufferCoord).a;
	if(fAOMask==1.0f)
		discard;

	EXPORT( float, E_fAO, fAOMask );


	//GBuffer_Depth.r
	EXPORT( float, E_fLinearDepth, fDepth );


	EXPORT( float, E_vPositionZ, mul(vPosition, g_matProj).z );
}