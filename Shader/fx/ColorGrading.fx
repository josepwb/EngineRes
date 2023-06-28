
texture g_txScene;
float2 g_RcpFrame;
float g_fLerpVal = 0.f;


sampler2D samRenderTarget : register(s0);
sampler2D samLUT : register(s1);
sampler2D samSecLUT : register(s2);


float4 MainPS( float2 vTexcoord: TEXCOORD, uniform bool bLerp ) : COLOR
{	
	float3 vColor = tex2D( samRenderTarget, vTexcoord).rgb;

	float2 Offset = float2(0.5f / 256.0f, 0.5f / 16.0f);
	float Scale = 15.0f / 16.0f; 

	float IntB = floor(vColor.b * 14.9999f) / 16.0f;
	float FracB = vColor.b * 15.0f - IntB * 16.0f;

	float U = IntB + vColor.r * Scale / 16.0f;
	float V = vColor.g * Scale;

	float3 RG0 = tex2D( samLUT, Offset + float2(U               , V) ).rgb;
	float3 RG1 = tex2D( samLUT, Offset + float2(U + 1.0f / 16.0f, V) ).rgb;
	
	if( bLerp)
	{
		float3 SecRG0 = tex2D( samSecLUT, Offset + float2( U               , V ) ).rgb;
		float3 SecRG1 = tex2D( samSecLUT, Offset + float2( U + 1.0f / 16.0f, V ) ).rgb;
		RG0	= lerp( SecRG0, RG0, g_fLerpVal );
		RG1	= lerp( SecRG1, RG1, g_fLerpVal );
	}

	return  float4( lerp( RG0, RG1, FracB ), 1);

}


technique MainNoLerp
{
    pass P0
    {
		PixelShader  = compile ps_3_0 MainPS( false);
    }	
}

technique MainWithLerp
{
    pass P0
    {
		PixelShader  = compile ps_3_0 MainPS( true);
    }	
}

