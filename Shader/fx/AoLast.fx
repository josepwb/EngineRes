#include "MSSAAO_h.fx"

sampler lowResAOTex	: register(s1);
sampler posTex	: register(s5);
sampler normTex	: register(s4);
sampler maskTex	: register(s0);
sampler shadowTex	: register(s6);

uniform extern int iSamplingCount = 14;
uniform extern float fAoColorPower = 1.6f;

float poissonDisk[] = {
	   -0.326212, -0.405805,
    0.962340, -0.194983,
   -0.840144, -0.073580,
    0.519456,  0.767022,
   -0.695914,  0.457137,
    0.185461, -0.893124,
    0.507431,  0.064425,
	};
	

/// 그림자가 어느정도 쎄기 이상일 시 처리하는 팩터. 아티스트 조절 값으로 빼줘야 함. 일단 고정
#define SHADOW_FACTOR 0.5f
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

float4 AoFirstPS( float2 tex : TEXCOORD0 ) : COLOR
{
	float fMaskP = tex2Dlod( maskTex, float4( tex, 0, 0)).a;
	if( fMaskP != 0)
		return float4( 0, 0, 0, 0);
	
	float occlusion = 0.0;
	float sampleCount = 0.0001;
	
	float3 depth = 0;
	float3 normal = 0;
	makeNormalDepthValue( normTex, posTex, tex, depth, normal );
	
	float fFactor = GetFactor( depth.r );
	[branch]
	if( fFactor <= 0)
		return 0;

#ifdef SHADOWONLY		
	// 라이트가 밝은 부분이면 역시 AO 스킵
	float fShadow = tex2D( shadowTex, tex).b;
	[branch]
	if( fShadow >= SHADOW_FACTOR)
		return 0;
#endif // SHADOWONLY
		
	float2 rangeMax = GetStepSize( abs(depth.z), 3.5f );
	
	[loop]
	for (float x = 1.f; x <= rangeMax.x % 16 ; x += 2.f)
	{
		for (float y = 1.f; y <= rangeMax.y % 16 ; y += 2.f)
		{
			ComputeOcclusion( posTex, maskTex, tex.xy + float2(x * fWidth, y * fHeight ),  normal,  depth.xyz, occlusion, sampleCount );
			ComputeOcclusion( posTex, maskTex, tex.xy + float2(-x * fWidth, y * fHeight ),  normal,  depth.xyz, occlusion, sampleCount );
			ComputeOcclusion( posTex, maskTex, tex.xy + float2(-x * fWidth, -y * fHeight ),  normal,  depth.xyz, occlusion, sampleCount );
			ComputeOcclusion( posTex, maskTex, tex.xy + float2(x * fWidth, -y * fHeight ) ,  normal,  depth.xyz, occlusion, sampleCount );			
		}
	}
	
	occlusion *= fFactor;
	
	return float4( occlusion / sampleCount, occlusion, sampleCount, 1.f);  
}

technique AOFirstTech
{
	pass P0
    {

		vertexShader	= NULL;
        pixelShader		= compile ps_3_0 AoFirstPS();
    }	
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	

	
float4 AoAvgPS(   float2 tex : TEXCOORD0 ) : COLOR
{
	float fMaskP = tex2Dlod( maskTex, float4( tex, 0, 0)).a;
	if( fMaskP != 0)
		return float4( 0, 0, 0, 0);
		
	float occlusion			= 0.0;
	float sampleCount	= 0.0001f;

	float3 depth = 0;
	float3 normal = 0;
	makeNormalDepthValue( normTex, posTex, tex, depth, normal );
	
	[branch]
	float fFactor = GetFactor( depth.r );
	if( fFactor <= 0)
		return 0;

#ifdef SHADOWONLY		
	// 라이트가 밝은 부분이면 역시 AO 스킵
	float fShadow = tex2D( shadowTex, tex).b;
	[branch]
	if( fShadow >= SHADOW_FACTOR)
		return 0;
#endif // SHADOWONLY
		
	float2 rangeMax = GetStepSize( abs(depth.z), 1.5f );
		

	[loop]
	for (float x = 1.0; x <= rangeMax.x % 16 ; x += 2.0)
	{
		for (float y = 1.0; y <= rangeMax.y % 16 ; y += 2.0)
		{
			ComputeOcclusion( posTex, maskTex, tex.xy + float2( x * fWidth, y * fHeight ), normal, depth, occlusion, sampleCount );
			ComputeOcclusion( posTex, maskTex, tex.xy + float2( -x * fWidth, y * fHeight ), normal, depth, occlusion, sampleCount );
			ComputeOcclusion( posTex, maskTex, tex.xy + float2( -x * fWidth, -y * fHeight ), normal, depth, occlusion, sampleCount );
			ComputeOcclusion( posTex, maskTex, tex.xy + float2( x * fWidth, -y * fHeight ), normal, depth, occlusion, sampleCount );
		}
	}
	
	occlusion *= fFactor;
	
	float3 upsample = Upsample( normTex, posTex, lowResAOTex, normal, depth, tex  );		
	return float4( max(upsample.x, occlusion / sampleCount), upsample.y + occlusion, upsample.z + sampleCount, 1.f); 
}

technique AOAvgTech
{
	pass P0
    {
		vertexShader	= NULL;
        pixelShader		= compile ps_3_0 AoAvgPS();
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



float4 AOLastPS( float2 tex : TEXCOORD0  ) : COLOR
{
	float fMaskP = tex2Dlod( maskTex, float4( tex, 0, 0)).a;
	if( fMaskP != 0)
		return float4( 1, 1, 1, 1);
		
	float occlusion			= 0.0;
	float sampleCount	= 0.0;
		
	float3 depth = 0;
	float3 normal = 0;
	makeNormalDepthValue( normTex, posTex, tex, depth, normal );
	
	[branch]
	float fFactor = GetFactor( depth.r );
	if( fFactor <= 0)
		return 1;
		
#ifdef SHADOWONLY		
	// 라이트가 밝은 부분이면 역시 AO 스킵
	float fShadow = tex2D( shadowTex, tex).b;
	[branch]
	if( fShadow >= SHADOW_FACTOR)
		return 1;
#endif // SHADOWONLY

	float2 rangeMax = GetStepSize( abs(depth.z), 1.f );
			
	[loop]
	for ( int i = 0 ; i < iSamplingCount % 15  ; i += 2 )
	{
		ComputeOcclusion( posTex, maskTex, tex + float2( poissonDisk[ i ] * fWidth, poissonDisk[ i + 1 ] * fHeight ) * rangeMax, 
									normal, depth, occlusion, sampleCount );    
	}

	occlusion *= fFactor;
	
	float3 upsample		=	Upsample( normTex, posTex, lowResAOTex, normal, depth, tex );
		
	float aoMax = max(upsample.x, occlusion / sampleCount);  
	float aoAverage = (upsample.y + occlusion) / (upsample.z + sampleCount);	
	float currentFrameAO = (1.f - aoMax) * (1.f - aoAverage);
	float AoColor =  currentFrameAO;
	return float4(AoColor, AoColor, AoColor, 1.f);
}

technique AOLastTech
{
    pass P0
    {
		vertexShader	= NULL;
        pixelShader		= compile ps_3_0 AOLastPS();
	}
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

float4 LastScenePS(in float2 wPos :TEXCOORD0) : COLOR
{
	return pow( tex2D( lowResAOTex, wPos ), fAoColorPower );
}


technique LastScene
{
    pass P0
    {
		vertexShader	= NULL;
        pixelShader		= compile ps_3_0 LastScenePS();
	}
}