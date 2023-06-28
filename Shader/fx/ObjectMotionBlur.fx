//-----------------------------------------------------------------------------
// File: ScreenMotionBlur.fx
//
// Desc: ������Ʈ �ȼ� ��Ǻ�
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Global constants
//-----------------------------------------------------------------------------


int g_numSamples = 15;

float depthScale = 1;
float g_fDevideVelocity = 1;

	
//-----------------------------------------------------------------------------
// Texture samplers
//-----------------------------------------------------------------------------
sampler s0 : register(s0);		// texture SceneColor;
sampler s1 : register(s1);		// texture Velocoty;
 

//-----------------------------------------------------------------------------
// Type: Pixel shader                                      
// Desc: Do Blur!!!!!
//-----------------------------------------------------------------------------
float4 blur_ps( in float4 texCoord : TEXCOORD0 ) : COLOR
{
	half4 o;
	
	texCoord.zw = 0;
		
	float2 velocity = tex2Dlod( s1, texCoord).xy;
	// Get the initial color at this pixel.   
	half4 color = tex2Dlod( s0, texCoord);   // sceneSampler
	
	if( length( velocity) > 0)
	{
		// %���� ���� ũ�� ������ ��´�. 15�� ��������.
		float loopCnt = (float)g_numSamples % 16;
		
		// ���̸� �����.
		velocity /= loopCnt;
		velocity *= g_fDevideVelocity;
		
		texCoord.xy += velocity; 
		half fFactorAssem = 1;
		for(float i = 1; i < loopCnt; ++i, texCoord.xy += velocity)   
		{   
			// Sample the color buffer along the velocity vector.   
			half4 currentColor = tex2Dlod( s0, texCoord);	// sceneSampler 
			half2 currentVelocity = tex2Dlod( s1, texCoord).xy;	// sceneSampler 
			
			// �ӵ��� 0�� ������ �ǵ��� �ʴ´�.
			half fLen = sign( length( currentVelocity));
			
			// Add the current color to our color sum.
			//float fFactor = (1 - i/loopCnt) * fLen;
			//fFactor *= 3;
			//fFactor = min( fFactor, 1);
			//color += currentColor * fFactor;	// ������ �������� Į�� ���͸� ���δ�.
			//fFactorAssem += fFactor;
			
			color += currentColor * fLen;
			fFactorAssem += 1 * fLen;
		}
		
		// Average all of the samples to get the final blur color.   
		o = color / fFactorAssem;
		o.a = 1;
		
		return o;
	}
	else
	{
		return color;
	}
}




//-----------------------------------------------------------------------------
// Name: ScreenMotionBlur
// Type: Technique                                     
// Desc: Do Blur!!!!!
//-----------------------------------------------------------------------------
technique Blur
{
	pass P0
	{
		PixelShader = compile ps_3_0 blur_ps();
	}
}







//-----------------------------------------------------------------------------
// Type: Pixel shader                                      
// Desc: Helper shader for visualizing depth/blurriness
//-----------------------------------------------------------------------------
float4 overlay_ps( in float2 vTexCoord : TEXCOORD0 ) : COLOR
{
	float4 Velocity = tex2D( s0, vTexCoord);
	
	Velocity.xy *= 20.0f;

	//return float4( BlurDepth.x/BlurDepth.y, BlurDepth.x, BlurDepth.y, 1);	
	return Velocity;
}

//-----------------------------------------------------------------------------
// Name: DepthBlurOverlay
// Type: Technique                                     
// Desc: Helper shader for visualizing depth/blurriness
//-----------------------------------------------------------------------------
technique Overlay
{
	pass P0
	{
		PixelShader = compile ps_3_0 overlay_ps();
	}
}
