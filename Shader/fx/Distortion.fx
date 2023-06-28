//-----------------------------------------------------------------------------
// File: Distortion.fx
//
// Desc: Distortion ȿ�� ����
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
// Ǯ��ũ�� ������� ����ŷ �ʿ� ���� ���� ����ؼ� ȭ�� ��ü�� �ְ�
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
// �ȼ����̴�
// ------------------------------------------------------------
float4 PS_MaskInfo( in float2 vTexCoord : TEXCOORD0 ) : COLOR
{   
	float4 C0 = tex2D( samRenderTarget, vTexCoord);	// ��������
	float4 Out = float4( C0.r, C0.g, 0, 1);
	
	if( Out.x == 0 && Out.y == 0)
	  return float4(0,0,0,1);
	
	Out.xy = Out.xy * 5;
	Out.xy += 1;
	Out.xy /= 2;
	return Out;
}

// ------------------------------------------------------------
// ��ũ��
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

