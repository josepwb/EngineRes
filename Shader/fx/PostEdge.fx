
sampler g_samSrcEdgeTest	: register(s0);
sampler g_samSrcEdge		: register(s1);
sampler g_samSrcColor		: register(s2);

float	g_fScreenWidth;
float	g_fScreenHeight;
float	g_fEdgePower;
float	g_fFactor	= 2.f;		// 색 진하기. 약하게 주면 연하게 나온다.


float offset[3] = { 0.0, 1.3846153846, 3.2307692308 }; 
float weight[3] = { 0.2270270270, 0.3162162162, 0.0702702703 }; 


float4 PostEdgeBlurV( in float2 Tex : TEXCOORD0 ) : COLOR
{			
	float4 Color = 0;
	Color = tex2D( g_samSrcEdgeTest, Tex ) * weight[0];
	
	for (int i = 1 ; i < 3 ; i++)
	{ 
		Color += tex2D( g_samSrcEdgeTest, Tex +  float2(0.f, offset[i] * g_fFactor)  / g_fScreenHeight) * weight[i]; 
		Color += tex2D( g_samSrcEdgeTest, Tex -  float2(0.f, offset[i] * g_fFactor)  / g_fScreenHeight) * weight[i]; 
	} 
    return Color;    
}


float4 PostEdgeBlurH( in float2 Tex : TEXCOORD0 ) : COLOR
{	
	float4 Color = 0;
	Color = tex2D( g_samSrcEdgeTest, Tex ) * weight[0];
	
	for (int i = 1 ; i < 3 ; i++)
	{ 
		Color += tex2D( g_samSrcEdgeTest, Tex +  float2(offset[i] * g_fFactor, 0.f) / g_fScreenWidth) * weight[i]; 
		Color += tex2D( g_samSrcEdgeTest, Tex -  float2(offset[i] * g_fFactor, 0.f) / g_fScreenWidth) * weight[i]; 
	} 
    
    return Color;

}


float4 PostEdgeAdd(in float2 Tex : TEXCOORD0 ) : COLOR
{				
	return float4( tex2D(g_samSrcEdgeTest, Tex).rgb * g_fEdgePower, 1);
}


float4 copy_scene(in float2 Tex : TEXCOORD0 ) : COLOR
{				
	float3 vOrg = tex2D( g_samSrcColor, Tex).rgb;
	
	return float4( vOrg.rgb, 1);
}


float4 mask_overlay_ps( in float2 Tex : TEXCOORD0 ) : COLOR
{
	float4 BlurDepth = abs(tex2D( g_samSrcColor, Tex));

	return float4( BlurDepth.rgb, 1);	
}


technique PostEdgeBlur
{
	pass P0
    {
		VertexShader = null;
		PixelShader  = compile ps_3_0 PostEdgeBlurH();
    }
    
    pass P1
    {
		VertexShader = null;
		PixelShader  = compile ps_3_0 PostEdgeBlurV();
    }
}

technique PostEdgeAddScene
{
	pass P0
    {
		VertexShader = null;
		PixelShader  = compile ps_3_0 PostEdgeAdd();
    }
}


technique CopyScene
{
	pass P0
	{
		PixelShader = compile ps_3_0 copy_scene();
	}
}


technique MaskOverlay
{
	pass P0
	{
		PixelShader = compile ps_3_0 mask_overlay_ps();
	}
}
