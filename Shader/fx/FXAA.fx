#include "Fxaa3_10.fx"


float2 g_RcpFrame;


sampler2D samRenderTarget : register(s0);


float4 MainPS( float2 vTexcoord: TEXCOORD ) : COLOR
{	
	FxaaTex tex = { samRenderTarget };
	float4 vColor = float4( FxaaPixelShader( vTexcoord, tex, g_RcpFrame.xy ).rgb, 1.f);

	return vColor;

}


technique MainTech
{
    pass P0
    {
		PixelShader  = compile ps_3_0 MainPS();
    }	
}