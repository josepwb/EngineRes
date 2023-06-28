//-----------------------------------------------------------------------------
// File: SSAO.fx
//
// Desc: Screen Space Ambient Occlusion
// 랜덤 벡터 생성
//  - http://wiki.gamedev.net/index.php/D3DBook:Screen_Space_Ambient_Occlusion
//  - http://kyruie.tistory.com/31
// 오클루젼 계산
//  - shaderx7 6.1
// halo removal : 적용 실패. 시간을 더 두고 볼것
// - http://www.gamedev.net/community/forums/topic.asp?topic_id=550699
// - 이 방법을 사용 하면 blur 패스가 필요 없어진댄다...
// - 그러나 전통적인 SSAO보다는 느려진다는데, 차라리 blur패스를 거치는게 나은지..
//-----------------------------------------------------------------------------

#define NUM_SAMPLE_NUM 16

// View dimensions
float4 vViewDimensions;

// SSAO parameters
float4 vSSAOParams = float4(0.0f, 30.0f, 4.0f, 200.0f);

// Inverse view projection matrix
float4 g_vProjInvZ;
float4 g_vProjInvW;

// for Gaussian ---------------------------
// Contains sampling offsets used by the techniques
float2 g_avSampleOffsets[13];
float4 g_avSampleWeights[13];
int g_nSampleCount = 13;


// Gaussian weights
float g_fWeight[6];

// Brightness value
float g_fBright = 0.5f;

// Samplers
sampler DepthSampler : register(s0);
sampler RandomSampler : register(s1);
sampler AOSampler : register(s2);
sampler NormalSampler : register(s3);

// Function to compute the final color
float4 finalColor(in float fValue)
{
    float sample = fValue;
    sample = saturate(fValue + 0.05f);
    sample = sample * 2;
    sample = pow(sample, 2);
    return float4(sample, sample, sample, 1);
}


// Function to compute the final normal
float3 finalNormal(in float3 norm)
{
    norm.z = -sqrt(1.0f - norm.x * norm.x - norm.y * norm.y);
    return norm;
}


//-----------------------------------------------------------------------------
// Function to read depth from the depth buffer
float readDepth(in float2 coord)
{
    float fDepthValue = abs(tex2D(DepthSampler, coord).r);
    float4 vDepthValue = float4(0, 0, fDepthValue, 1);
    return (dot(vDepthValue, g_vProjInvZ) / dot(vDepthValue, g_vProjInvW));
}

// Main pixel shader
float4 PSmainCRYTECKadjustGDWIKI(in float2 screenTC : TEXCOORD0) : COLOR
{
    const float3 pSphere[10] = {
        float3(-0.010735935, 0.01647018, 0.0062425877),
        float3(-0.06533369, 0.3647007, -0.13746321),
        float3(-0.6539235, -0.016726388, -0.53000957),
        float3(0.40958285, 0.0052428036, -0.5591124),
        float3(-0.1465366, 0.09899267, 0.15571679),
        float3(-0.44122112, -0.5458797, 0.04912532),
        float3(0.03755566, -0.10961345, -0.33040273),
        float3(0.08237623, 0.2870656, 0.036109276),
        float3(0.5372537, -0.0736818, -0.302044),
        float3(-0.085063465, 0.15849054, -0.06448898)
    };

    float2 vPixelNorm = tex2D(NormalSampler, screenTC).xy;
    float fDepthCenter = readDepth(screenTC);

    float fDotAverage = 0.0f;

    // Random rotation for the sample vectors
    float3x3 RandomRotMatrix;
    RandomRotMatrix._11 = 0.6367f;
    RandomRotMatrix._12 = -0.5137f;
    RandomRotMatrix._13 = -0.5752f;
    RandomRotMatrix._21 = -0.8016f;
    RandomRotMatrix._22 = -0.4654f;
    RandomRotMatrix._23 = -0.3739f;
    RandomRotMatrix._31 = 0.0258f;
    RandomRotMatrix._32 = -0.7192f;
    RandomRotMatrix._33 = 0.6949f;

    for (int i = 0; i < g_nSampleCount; i++)
    {
        float3 vec;
        vec.x = g_avSampleOffsets[i].x * vViewDimensions.x;
        vec.y = g_avSampleOffsets[i].y * vViewDimensions.y;
        vec.z = 1.0f;

        vec.xy = mul(RandomRotMatrix, vec.xy);
        vec.xyz = normalize(vec.xyz);
        vec.xyz = normalize(finalNormal(vPixelNorm) * vec.xyz);
        vec.xyz = (vec.xyz * g_avSampleOffsets[i].y * vSSAOParams.y + vPixelNorm * vSSAOParams.z);
        vec.xyz = normalize(vec.xyz);

        float fDepth = readDepth(screenTC + vec.xy);
        float3 vSample = float3(vec.xy * fDepth, fDepth);
        float3 vSphere = pSphere[i % 10];

        float fAngle = dot(vSample, vSphere);
        fDotAverage += fAngle;
    }

    fDotAverage /= g_nSampleCount;
    fDotAverage = max(0.0f, pow(fDotAverage * fDotAverage * fDotAverage, 3.0f));

    float fAO = max(0.0f, 1.0f - vSSAOParams.x * fDotAverage);
    float fDepth = readDepth(screenTC);
    float4 vAOColor = tex2D(AOSampler, screenTC);

    float fBlend = pow(1.0f - fDepth, vSSAOParams.w);

    float fResult = 1.0f - (1.0f - vAOColor.r) * (1.0f - fAO);
    fResult = lerp(vAOColor.r, fResult, fBlend);

    return finalColor(fResult);
}

technique Tmain
{
    pass P0
    {
		PixelShader  = compile ps_3_0 PSmainCRYTECKadjustGDWIKI();
    }
}
//-----------------------------------------------------------------------------

// --------------------- denoise -------------------------------------------

float4 Blur4x4PS(in float2 vScreenPosition : TEXCOORD0) : COLOR
{
    float fFactorX = 1 / vViewDimensions.x;
    float fFactorY = 1 / vViewDimensions.y;
    float2 offset = float2(0.5f * fFactorX, 0.5f * fFactorY);
    vScreenPosition += offset;

    float sample = 0.0f;
    for (int x = 0; x < 4; x++)
    {
        for (int y = 0; y < 4; y++)
        {
            float2 vSamplePosition = vScreenPosition + float2((x - 2) * fFactorX, (y - 2) * fFactorY);
            sample += tex2D(AOSampler, vSamplePosition).r;
        }
    }

    sample *= 0.0625f; // sample = sample / 16.0f;

    return float4(sample, sample, sample, 1);
}

technique Blur4x4
{
    pass P0
    {
        PixelShader = compile ps_3_0 Blur4x4PS();
    }
}

//-----------------------------------------------------------------------------


// --------------------- Blur4x4BaiasEdge -------------------------------------

float4 Blur4x4BaiasEdgePS(in float2 vScreenPosition : TEXCOORD0) : COLOR
{
    float fFactorX = 1 / vViewDimensions.x;
    float fFactorY = 1 / vViewDimensions.y;
    float2 offset = float2(0.5f * fFactorX, 0.5f * fFactorY);
    vScreenPosition += offset;

    float sample = 0.0f;
    float cnt = 0.0000001f; // divide by zero prevention

    for (int x = 0; x < 4; x++)
    {
        for (int y = 0; y < 4; y++)
        {
            float2 vSamplePosition = vScreenPosition + float2((x - 2) * fFactorX, (y - 2) * fFactorY);

            // Random sampler index with edge setting
            if (tex2D(RandomSampler, vSamplePosition).r < 0.5f)
            {
                sample += tex2D(AOSampler, vSamplePosition).r;
                cnt += 1.0f;
            }
        }
    }

    sample /= cnt;

    return float4(sample, sample, sample, 1);
}

technique Blur4x4BaiasEdge
{
    pass P0
    {
        PixelShader = compile ps_3_0 Blur4x4BaiasEdgePS();
    }
}


//-----------------------------------------------------------------------------
float fFactorX = 1.0f / vViewDimensions.x;
float fFactorY = 1.0f / vViewDimensions.y;

float4 PSexpandDarkforce(in float2 vTexCoord : TEXCOORD0) : COLOR
{
    float2 texOffset = float2(fFactorX, fFactorY);
    float4 texColor;

    // 중
    texColor = tex2D(AOSampler, vTexCoord);
    float fV = min(texColor.g, 1.0f);

    // 상
    texColor = tex2D(AOSampler, vTexCoord - float2(0, fFactorY));
    fV = min(texColor.r, fV);
    // 하
    texColor = tex2D(AOSampler, vTexCoord + float2(0, fFactorY));
    fV = min(texColor.r, fV);
    // 좌
    texColor = tex2D(AOSampler, vTexCoord - float2(fFactorX, 0));
    fV = min(texColor.r, fV);
    // 우
    texColor = tex2D(AOSampler, vTexCoord + float2(fFactorX, 0));
    fV = min(texColor.r, fV);

    // 좌상
    texColor = tex2D(AOSampler, vTexCoord - texOffset);
    fV = min(texColor.r, fV);
    // 좌하
    texColor = tex2D(AOSampler, vTexCoord - float2(fFactorX, -fFactorY));
    fV = min(texColor.r, fV);
    // 우상
    texColor = tex2D(AOSampler, vTexCoord + float2(fFactorX, -fFactorY));
    fV = min(texColor.r, fV);
    // 우하
    texColor = tex2D(AOSampler, vTexCoord + texOffset);
    fV = min(texColor.r, fV);

    return float4(fV, fV, fV, 1);
}

technique TexpandDarkforce
{
	pass P0
	{
		PixelShader = compile ps_3_0 PSexpandDarkforce();
	}
}
//-----------------------------------------------------------------------------


float4 PSexpandBrightforce(in float2 vTexCoord : TEXCOORD0) : COLOR
{
    float2 texOffset = float2(fFactorX, fFactorY);
    float4 texColor;

    // 중
    texColor = tex2D(DepthSampler, vTexCoord);
    float fV = max(texColor.r, 0.0f);

    // 상
    texColor = tex2D(DepthSampler, vTexCoord - float2(0, fFactorY));
    fV = max(texColor.r, fV);
    // 하
    texColor = tex2D(DepthSampler, vTexCoord + float2(0, fFactorY));
    fV = max(texColor.r, fV);
    // 좌
    texColor = tex2D(DepthSampler, vTexCoord - float2(fFactorX, 0));
    fV = max(texColor.r, fV);
    // 우
    texColor = tex2D(DepthSampler, vTexCoord + float2(fFactorX, 0));
    fV = max(texColor.r, fV);

    // 좌상
    texColor = tex2D(DepthSampler, vTexCoord - texOffset);
    fV = max(texColor.r, fV);
    // 좌하
    texColor = tex2D(DepthSampler, vTexCoord - float2(fFactorX, -fFactorY));
    fV = max(texColor.r, fV);
    // 우상
    texColor = tex2D(DepthSampler, vTexCoord + float2(fFactorX, -fFactorY));
    fV = max(texColor.r, fV);
    // 우하
    texColor = tex2D(DepthSampler, vTexCoord + texOffset);
    fV = max(texColor.r, fV);

    return float4(fV, fV, fV, 1);
}

technique TexpandBrightforce
{
	pass P0
	{
		PixelShader = compile ps_3_0 PSexpandBrightforce();
	}
}
//-----------------------------------------------------------------------------




//-----------------------------------------------------------------------------
float4 PScopy( in float2 vTexCoord : TEXCOORD0 ) : COLOR
{
	float fVal = tex2D( AOSampler, vTexCoord).r;
	return float4( fVal, fVal, fVal, 1);
}

technique Tcopy
{
	pass P0
	{
		PixelShader = compile ps_3_0 PScopy();
		//PixelShader = compile ps_3_0 PSexpandDarkforce();
	}
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
float4 GaussBlurPS(in float2 vScreenPosition : TEXCOORD0) : COLOR
{
    float sample = 0.0f;
    
    for (int i = 0; i < 5; i++)
    {
        sample += g_avSampleWeights[i] * tex2D(AOSampler, vScreenPosition + g_avSampleOffsets[i]).r;
    }

    return float4(sample, sample, sample, 1);
}

technique GaussBlur
{
    pass P0
    {
        PixelShader = compile ps_3_0 GaussBlurPS();
    }
}

float4 GaussBlurPSX(in float2 vTexCoord : TEXCOORD0) : COLOR
{
    float weightFactorN[NUM_GAUSS];
    float weightFactorP[NUM_GAUSS];

    for (int i = 0; i < NUM_GAUSS; i++)
    {
        weightFactorN[i] = -i / vViewDimensions.x;
        weightFactorP[i] = i / vViewDimensions.x;
    }

    float Color = 0.0f;
    bool bIgnoreN = false;
    bool bIgnoreP = false;
    float fWeightSum = 0.0000001f;

    float2 vTexN, vTexP;
    for (int i = 0; i < NUM_GAUSS; i++)
    {
        vTexN = vTexCoord + float2(weightFactorN[i], 0);
        vTexP = vTexCoord + float2(weightFactorP[i], 0);

        if (i > 0)
        {
            if (!bIgnoreN)
                bIgnoreN = (tex2D(DepthSampler, vTexN).r > 0.9f) ? true : false;
            if (!bIgnoreP)
                bIgnoreP = (tex2D(DepthSampler, vTexP).r > 0.9f) ? true : false;
        }

        if (bIgnoreN && bIgnoreP)
            break;

        if (!bIgnoreN)
        {
            Color += g_fWeight[i] * tex2D(AOSampler, vTexN).r;
            fWeightSum += g_fWeight[i];
        }

        if (!bIgnoreP)
        {
            Color += g_fWeight[i] * tex2D(AOSampler, vTexP).r;
            fWeightSum += g_fWeight[i];
        }
    }

    Color = Color / fWeightSum;

    return float4(Color, Color, Color, 1);
}

technique GaussBlurX
{
    pass P0
    {
        PixelShader = compile ps_3_0 GaussBlurPSX();
    }
}

float4 GaussBlurPSY(in float2 vTexCoord : TEXCOORD0) : COLOR
{
    float weightFactorN[NUM_GAUSS];
    float weightFactorP[NUM_GAUSS];

    for (int i = 0; i < NUM_GAUSS; i++)
    {
        weightFactorN[i] = -i / vViewDimensions.y;
        weightFactorP[i] = i / vViewDimensions.y;
    }

    float Color = 0.0f;
    bool bIgnoreN = false;
    bool bIgnoreP = false;
    float fWeightSum = 0.0000001f;

    float2 vTexN, vTexP;
    for (int i = 0; i < NUM_GAUSS; i++)
    {
        vTexN = vTexCoord + float2(0, weightFactorN[i]);
        vTexP = vTexCoord + float2(0, weightFactorP[i]);

        if (i > 0)
        {
            if (!bIgnoreN)
                bIgnoreN = (tex2D(DepthSampler, vTexN).r > 0.9f) ? true : false;
            if (!bIgnoreP)
                bIgnoreP = (tex2D(DepthSampler, vTexP).r > 0.9f) ? true : false;
        }

        if (bIgnoreN && bIgnoreP)
            break;

        if (!bIgnoreN)
        {
            Color += g_fWeight[i] * tex2D(AOSampler, vTexN).r;
            fWeightSum += g_fWeight[i];
        }

        if (!bIgnoreP)
        {
            Color += g_fWeight[i] * tex2D(AOSampler, vTexP).r;
            fWeightSum += g_fWeight[i];
        }
    }

    Color = Color / fWeightSum;

    return finalColor(Color);
}

technique GaussBlurY
{
    pass P0
    {
        PixelShader = compile ps_3_0 GaussBlurPSY();
    }
}

//-----------------------------------------------------------------------------






