struct VS_OUTPUT
{
    float4 Pos			: POSITION;
};

float4	ClearMain( VS_OUTPUT In ) : COLOR
{
	float fMaxDist = 1000000;	// 우리가 안쓰는 매우 큰 값
	return float4(fMaxDist,fMaxDist,fMaxDist,1);
}

Technique Clear
{
	pass P0 
	{
		PixelShader = compile ps_2_0 ClearMain();
	}
}

sampler DiffuseMap : register(s0);

struct RF_OUTPUT
{
    float4 Pos			: POSITION;
	float2 vDiffuseCoord : TEXCOORD0;
};

float4	RenderFloatPS( RF_OUTPUT In ) : COLOR
{
	float4 vDiffuseColor = tex2D( DiffuseMap, In.vDiffuseCoord );
	
	//깊이맵 값을 fMaxDist 값으로 나누면 깊이맵에 렌더링된 부분이 검은색으로만 나와서 원근을 확인할 수 없음.
	//깊이값에 따라 색이 다르게 나타나게 하기 위해 fMaxDist보다 작은 값으로 나눔.
	float c = vDiffuseColor.r/10000.0f;
	return float4(c,c,c,1);
}

float4	RenderAlphaPS( RF_OUTPUT In ) : COLOR
{
	float4 vDiffuseColor = tex2D( DiffuseMap, In.vDiffuseCoord );
	
	float c = vDiffuseColor.a;
	return float4(c,c,c,c);
}

Technique RenderFloatRenderTarget
{
	pass P0 
	{
		PixelShader = compile ps_2_0 RenderFloatPS();
	}
}

Technique RenderAlpha
{
	pass P0 
	{
		PixelShader = compile ps_2_0 RenderAlphaPS();
	}
}













//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
// Combine Common ShadowMap & Double ShadowMap

sampler CommonShadowMap: register(s0);
sampler DoubleShadowMap: register(s1);

float4	CombineDoubleShadowMapPS( float2 vTexcoord : TEXCOORD0) : COLOR
{
	float fCommonDepth = tex2D( CommonShadowMap, vTexcoord).r;
	float fDoubleDepth = tex2D( DoubleShadowMap, vTexcoord).r;

	return float4(fCommonDepth,fDoubleDepth,0,1);
}

Technique CombineDoubleShadowMap
{
	pass P0 
	{
		PixelShader = compile ps_2_0 CombineDoubleShadowMapPS();
	}
}
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------










sampler StaticShadowMap: register(s0);

float4	RenderShadowMapFromStaticShadowMapPS( float2 vTexcoord : TEXCOORD0 ) : COLOR
{
	return tex2D(StaticShadowMap, vTexcoord).x;
}

Technique RenderShadowMapFromStaticShadowMap
{
	pass P0 
	{
		PixelShader = compile ps_2_0 RenderShadowMapFromStaticShadowMapPS();
	}
}



//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
// Combine StaticShadowMap & DynamicShadowMap & DoubleShadowMap

sampler StaticShadowMapResult: register(s0);
sampler DynamicShadowMapResult: register(s1);
sampler DoubleShadowMapResult: register(s2);

float4	CombineShadowMapPS( float2 vTexcoord : TEXCOORD0) : COLOR
{
	float fStaticDepth = tex2D( StaticShadowMapResult, vTexcoord).r;
	float fDynamicDepth = tex2D( DynamicShadowMapResult, vTexcoord).r;
	float fDoubleDepth = tex2D( DoubleShadowMapResult, vTexcoord).r;


	float4 vResult = float4( min(fStaticDepth,fDynamicDepth), fDoubleDepth, 0, 1 );
	vResult.xy += max(vResult.xy/1000.0f, 0);

	return vResult;
}

Technique CombineShadowMap
{
	pass P0 
	{
		PixelShader = compile ps_2_0 CombineShadowMapPS();
	}
}
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------