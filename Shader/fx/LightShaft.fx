
sampler depthSampler : register(s0);
sampler sunSampler : register(s1);
sampler blurSampler : register(s2);
sampler colorSampler : register(s3);
sampler maskSampler : register(s4);


float fDensity = 0.7f;
float fDecay = 0.95;
float2 vScreenSunPos;	// 0~1
float fSunSize = 0.5f;	// 0~1~
float fMaskSize = 1.0f;	// 0~1~
float fExposure = 0.2f;
float fWeight = 0.7f;
int nSamplingCount = 7;
float2 fPrecisionDivide = float2( 3, 3);	/// x: read y: write
int bSunTexture = 0;
int bMaskTexture = 0;
float fApplyDepthFactor = 0;
float fOpacity = 1;
float fFovX = 1;


float4 BlurPS(float2 texCoord : TEXCOORD0) : COLOR0  
{  
	// Store initial sample.
	float4 blurSam = tex2D( blurSampler, texCoord);
	float3 color = blurSam.rgb * fPrecisionDivide.x;
	// Calculate vector from pixel to light source in screen space.
	float2 deltaTexCoord = (texCoord - vScreenSunPos.xy);
	// apply depth 
	float fSamplingDensity = fDensity + fDensity * blurSam.a;
	// Divide by number of samples and scale by control factor.
	deltaTexCoord *= 1.0f / nSamplingCount * fSamplingDensity;
	// Set up illumination decay factor.
	float illuminationDecay = 1.0f;
	// Evaluate summation from Equation 3 NUM_SAMPLES iterations.
	for (int i = 0; i < nSamplingCount % 30; i++)
	{
		// Step sample location along ray.
		texCoord -= deltaTexCoord;
		// Retrieve sample at new location.
		float3 sample = tex2D( blurSampler, texCoord).rgb * fPrecisionDivide.x;
		// Apply sample attenuation scale/decay factors.  
		sample *= illuminationDecay * fWeight;  
		// Accumulate combined color.  
		color += sample;  
		// Update exponential decay factor.  
		illuminationDecay *= fDecay;  
	}  
	// Output final color with a further scale control factor.  
	float3 resultColor = color * fExposure;
	return float4( resultColor / fPrecisionDivide.y, blurSam.a);  
}  




float4 MakeOcclusionPS(float2 texCoord : TEXCOORD0) : COLOR0  
{  
	float fDepth = abs( tex2D( depthSampler, texCoord)).r;
	float3 vColor = 0;
	
	if( fDepth >= 1)
	{
		if( bSunTexture == 1)
		{
			/// 태양 텍스쳐 기준의 샘플링 좌표.
			float2 vSunCoord = float2( 0.5f, 0.5f) + ( ( texCoord - vScreenSunPos) * ( 1.0f / float2( fSunSize / fFovX, fSunSize)) );
			vColor = abs( tex2D( sunSampler, vSunCoord)).rgb;
		}
		else
		{	
			vColor = 1;
		}
	}

	/// 알파 채널에는 뎁스 팩터를 저장.
	return float4( vColor / fPrecisionDivide.y, fApplyDepthFactor * fDepth);
}



float4 AccumPS(float2 texCoord : TEXCOORD0) : COLOR0
{
	float3 color = tex2D( colorSampler, texCoord);
	float3 blur = tex2D( blurSampler, texCoord);

	if( bMaskTexture == 1)
	{
		/// 태양 텍스쳐 기준의 샘플링 좌표.
		float2 vSunCoord = float2( 0.5f, 0.5f) + ( ( texCoord - vScreenSunPos) * ( 1.0f / (fSunSize * 4)) );
		float3 vMask = abs( tex2D( maskSampler, vSunCoord)).rgb;	
		blur = blur * vMask;
	}

	return float4( color + (blur * fOpacity), 1);
}


float4 NoProcessPS(float2 texCoord : TEXCOORD0) : COLOR0
{
	float3 color = tex2D( colorSampler, texCoord);
	
	return float4( color, 1);
}





technique MakeOcclusion
{
	pass P0
	{
		PixelShader  = compile ps_3_0 MakeOcclusionPS();
	}
}


technique Blur
{
	pass P0
	{
		PixelShader  = compile ps_3_0 BlurPS();
	}
}


technique Accum
{
	pass P0
	{
		PixelShader  = compile ps_3_0 AccumPS();
	}
}


technique NoProcess
{
	pass P0
	{
		PixelShader  = compile ps_3_0 NoProcessPS();
	}
}
