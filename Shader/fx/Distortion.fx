//-----------------------------------------------------------------------------
// File: Distortion.fx
//
// Desc: Distortion 효과 적용
//-----------------------------------------------------------------------------

#include "DistortionMask_h.fx"


//-----------------------------------------------------------------------------
// Texture samplers
//-----------------------------------------------------------------------------
sampler samRenderTarget : register(s0);
sampler samMaskingMap : register(s1);


//-----------------------------------------------------------------------------
// Type: Pixel shader                                      
// Desc: Distortion shader
// 풀스크린 디스토션은 마스킹 필요 없이 직접 계산해서 화면 전체를 왜곡
//-----------------------------------------------------------------------------
float4 FullScreenDistortion_PS( float2 vTexcoord: TEXCOORD ) : COLOR
{
	float4 colDistorted = tex2D( samRenderTarget, vTexcoord + GetDistortion( vTexcoord));
	colDistorted.a = 1.0f;
	return colDistorted;
}


float4 Distortion_PS( float2 vTexcoord: TEXCOORD0, float2 vPos: VPOS ) : COLOR
{
	float2 vDistirtion = tex2D( samMaskingMap, vTexcoord); 
	float4 colDistorted = tex2D( samRenderTarget, vTexcoord + vDistirtion);
	colDistorted.a = 1.0f;
		
	return colDistorted;
}


float4 Masking_PS() :COLOR0
{
	return 1;
}




// ------------------------------------------------------------
// 픽셀셰이더
// ------------------------------------------------------------
float4 PS_MaskInfo( in float2 vTexCoord : TEXCOORD0 ) : COLOR
{   
	float4 C0 = tex2D( samRenderTarget, vTexCoord);	// 누적버퍼
	float4 Out = float4( C0.r, C0.g, 0, 1);
	
	if( Out.x == 0 && Out.y == 0)
	  return float4(0,0,0,1);
	
	Out.xy = Out.xy * 5;
	Out.xy += 1;
	Out.xy /= 2;
	return Out;
}

// ------------------------------------------------------------
// 테크닉
// ------------------------------------------------------------
technique MaskInfo
{
    pass P0
    {
        PixelShader  = compile ps_2_0 PS_MaskInfo();
    }
}




//-----------------------------------------------------------------------------
// Technique
//-----------------------------------------------------------------------------

technique FullScreenDistortion
{
    pass P0
    {
        PixelShader  = compile ps_3_0 FullScreenDistortion_PS();
    }
}

technique Distortion
{
    pass P0
    {
        PixelShader  = compile ps_3_0 Distortion_PS();
    }
}

