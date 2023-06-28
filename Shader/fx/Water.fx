float4x4    g_mModelViewProj;
float4x4    g_mModelViewInv;
float4x4    g_mTextureTrans;						
float4x4	g_matViewProjInv;
float4		g_vResolution = float4( 800, 600, 0.5f/800, 0.5f/600);

float4      g_vFogColor;                            // fog color
float3      g_vFogParams;                           // used for fog distance calcs: .x = fog start, .y = fog end, .z = end - start
float3		g_vCameraPos;

float		g_fTime;

// 물 컨트롤 파라미터들
float4		g_vBumpUVScale;

float4		g_vBumpMove1;
float4		g_vBumpMove2;

float		g_fBumpAdjustFactor;

float4		g_vBumpWeight1;
float4		g_vBumpWeight2;
float4		g_vBumpWeight3;
float4		g_vBumpWeight4;
float4		g_vBumpColorToVector;

float		g_fLimitDepth;							// 1 / 한계심도
float3		g_fWaterRGBHalflife;					// 1 / 반감기(깊이값)
float		g_fFresnelConstant;
float		g_fReflectAdjust;
bool		g_bUseReflectionMap;
float		g_fReflectionDistortion = 0.15f;
float		g_fSpecularScale;

float3		g_vHalfVector;
float4		g_vDiffuseColor;

float3		g_vWaterMaterial;

float2		g_fRefractAttenuation;


//vertex wave 관련 파라미터
float g_fScale;
float g_fAmplitude1;
float g_fPhase1;


//Shore 관련
texture		g_tWaterShore;
float4		g_vShoreInfo; //xy:UVScale, z:Intensity, w:Blending


//Screen-Quad의 View-공간 정점 위치 정보
float3 g_vFarClipCornerInView;


sampler samDiffuseMap : register(s0);
sampler samBumpMap : register(s1);
sampler samBumpMap2 : register(s2);
sampler samMaskingMap : register(s3);
sampler samDepthBuffer : register(s4);
sampler samWaterShore : register(s5);
sampler samReflectCube : register(s6);


///////////////////////////////////////////////////////////////////////  
//  Fog Helper Functions

float FogValue(float fPoint)
{
    float fFogEnd = g_vFogParams.y;
    float fFogDist = g_vFogParams.z;
    
    return saturate((fFogEnd - fPoint) / fFogDist);
}

float GetFresnel(float3 vCameraDir, float3 vBump)
{
 	float camAngle = saturate(dot(normalize(vCameraDir), vBump));
 	
 	float f, f2, f5;		// 프레넬 항/2제곱/5제곱
 	
 	f = 1 - camAngle;
 	f2 = f * f;
 	f5 = f2 * f2 * f;
 	
 	float t1 = 1 - g_fFresnelConstant;
 	
 	return f5 * g_fFresnelConstant + t1;
}

float4 ReconstructPosFromDepth(float2 vScreencood, float fDepth)
{
	float3 vRay;
	vRay.xy = lerp(-g_vFarClipCornerInView.xy, g_vFarClipCornerInView.xy, vScreencood);
	vRay.z = g_vFarClipCornerInView.z;
	return float4(vRay*fDepth, 1);
}

float4 GetDepthColor(float2 vScreenCoord, float fWaterHeight)
{	
	float fDepth = abs(tex2D(samDepthBuffer, vScreenCoord.xy).x);
	float3 vViewPos = ReconstructPosFromDepth(vScreenCoord.xy, fDepth);
	float4 vWorldPos = mul(float4(vViewPos,1), g_mModelViewInv);
	
	float3 vec = g_vCameraPos - vWorldPos;
	float len = length(vec);
	
	float h1 = g_vCameraPos.z - fWaterHeight;
	float h2 = fWaterHeight - vWorldPos.z;
	
	float s = h2 / (h1 + h2);
	float d = len * s;	
 	
   	float3 ld = d.xxx * g_fWaterRGBHalflife.rgb;
  	
  	float4 vResult;
  	vResult.r = saturate(exp(-ld.r));
  	vResult.g = saturate(exp(-ld.g));
  	vResult.b = saturate(exp(-ld.b)); 	
	vResult.a = saturate(d * g_fLimitDepth);
	
	return vResult;
}
///////////////////////////////////////////////////////////////////////  



struct Wave {
  float frequency;  // 2*PI / wavelength
  float amplitude;   // amplitude
  float phase; // speed * 2*PI / wavelength
  float2 dir;
};


// wave functions
float evaluateWave(Wave w, float2 pos, float t)
{
  return w.amplitude * sin( dot(w.dir, pos)*w.frequency + t*w.phase);
}

// derivative of wave function
float evaluateWaveDeriv(Wave w, float2 pos, float t)
{
  return w.frequency*w.amplitude * cos( dot(w.dir, pos)*w.frequency + t*w.phase); 
}

// sharp wave functions
float evaluateWaveSharp(Wave w, float2 pos, float t, float k)
{
  return w.amplitude * pow(sin( dot(w.dir, pos)*w.frequency + t*w.phase)* 0.5 + 0.5 , k);
}

// derivative of sharp wave function
float evaluateWaveDerivSharp(Wave w, float2 pos, float t, float k)
{
  return k*w.frequency*w.amplitude 
			* pow(sin( dot(w.dir, pos)*w.frequency + t*w.phase)* 0.5 + 0.5 , k - 1) 
			* cos( dot(w.dir, pos)*w.frequency + t*w.phase);
}
  
	
struct SWaterOutput
{
    float4 vPosition	: POSITION;
    float4 vBumpCoord	: TEXCOORD0;
    float4 vBumpCoord2	: TEXCOORD1;
    float3 vCameraVec	: TEXCOORD2;
    float3 vTangent		: TEXCOORD3;
    float3 vNormal		: TEXCOORD4;
    float4 vWorldPos	: TEXCOORD5;
};


SWaterOutput WaterPlaneVS(	float3	vPosition	: POSITION,
							float	vDepth		: TEXCOORD0
							)
{
	SWaterOutput sOutput;
	
	float4 vFinalVertex;
	
	vFinalVertex.xyz = vPosition.xyz;
	vFinalVertex.w = 1.0f;


	//----------------------------------------------------------------------------
	// wave create
	
	//TODO: 현재 vDepth 값을 제대로 계산하지 않는다.
	//제대로 계산하게 되면 사용하자.
	float fDepthScale = 1;//tanh(vDepth/8000.0f);

	float fAmplitude =(g_fAmplitude1) * (fDepthScale);
	Wave wave[2] = {
		{ 0.15f, fAmplitude, g_fPhase1, float2(-1.0f, 0.0f) },
		{ 0.3f, fAmplitude/2.0f, g_fPhase1*2.6f, float2(-0.7f, 0.7f) },
	};

	float ddx = 0.0f, ddy = 0.0f;

	float chopeness =2.0f;
	
	for(int i=0; i<2; i++) 
	{
    	vFinalVertex.z += evaluateWaveSharp(wave[i], vFinalVertex.xy /(g_fScale+0.0001f), g_fTime, chopeness)*g_fScale;
    	float deriv = evaluateWaveDerivSharp(wave[i], vFinalVertex.xy /(g_fScale+0.0001f), g_fTime, chopeness);
    	ddx += deriv * wave[i].dir.x;
    	ddy += deriv * wave[i].dir.y;
    }
    //----------------------------------------------------------------------------


	//----------------------------------------------------------------------------
	// tangent space basis vector
	
	//float3 vBinormal = float3(1, 0, ddx);
    float3 vTangent = float3(0, 1, ddy);
    float3 vNormal = float3(-ddx, -ddy, 1);

    //sOutput.vBinormal =normalize(vBinormal);
    sOutput.vTangent =normalize(vTangent);
    sOutput.vNormal = normalize(vNormal);
    //----------------------------------------------------------------------------
  
	//result position
	sOutput.vPosition = mul(vFinalVertex, g_mModelViewProj);			// project to screen
	
	
	//----------------------------------------------------------------------------
	// bump texture coordinate
	
	sOutput.vBumpCoord.xy = vPosition.xy * g_vBumpUVScale.x + frac(g_fTime.xx * g_vBumpMove1.xy*2.0f);
	sOutput.vBumpCoord.zw = vPosition.xy * g_vBumpUVScale.y + frac(g_fTime.xx * g_vBumpMove1.zw*2.0f);
	sOutput.vBumpCoord2.xy = vPosition.xy * g_vBumpUVScale.z + frac(g_fTime.xx * g_vBumpMove2.xy*2.0f);
	sOutput.vBumpCoord2.zw = vPosition.xy * g_vBumpUVScale.w + frac(g_fTime.xx * g_vBumpMove2.zw*2.0f);
	//----------------------------------------------------------------------------

	sOutput.vCameraVec = normalize(g_vCameraPos - vPosition);

	
	//--------------------------------------------------------------------------
	// refraction texcoord 
	//sOutput.vTexCoords = mul(vFinalVertex, g_mTextureTrans);
	//--------------------------------------------------------------------------
	
	sOutput.vWorldPos.xyz = vFinalVertex.xyz;
	sOutput.vWorldPos.w = sOutput.vPosition.z;

	return sOutput;		
}




float3 GetBump( SWaterOutput In)
{
	//--------------------------------------------------------------------------
	// Calculate Normal
	float4 bump = tex2D(samBumpMap, In.vBumpCoord.xy);
	float4 bump2 = tex2D(samBumpMap, In.vBumpCoord.zw);
	float4 bump3 = tex2D(samBumpMap2, In.vBumpCoord2.xy);
	float4 bump4 = tex2D(samBumpMap2, In.vBumpCoord2.zw);
	
	bump *= g_vBumpWeight1;
	bump += bump2 * g_vBumpWeight2;
	bump += bump3 * g_vBumpWeight3;
	bump += bump4 * g_vBumpWeight4;

	bump += g_vBumpColorToVector;
					
	float3x3 matToTangent;
	matToTangent[0] = cross(In.vTangent,In.vNormal);
	matToTangent[1] = In.vTangent;
	matToTangent[2] = In.vNormal;
	bump.xyz =mul(matToTangent, bump.xyz);

	return bump.xyz;
}

float4 GetRefractAdjust( float3 bump, float3 vWorldPos, float fNdotV)
{
	//카메라와 가까운 영역은 굴절 정도를 감쇠.
	float fDistViewToWater = length(g_vCameraPos - vWorldPos);
	float fDistAdjuctFactor = pow(min(fDistViewToWater/g_fRefractAttenuation.x, 1.0f),g_fRefractAttenuation.y);
	return float4( bump.xyz, 1) * g_fBumpAdjustFactor * fDistAdjuctFactor * fDistAdjuctFactor * 20 * fNdotV;	
}

float3 GetReflectionHighlight( float3 bump, float3 vCameraVec, float fNdotV)
{	
	float3 H = g_vHalfVector + vCameraVec;
	H = normalize(H);
	float s = saturate(dot(bump.rgb, H));
	float dl = saturate(sign(fNdotV));
	return pow(s, 50) * dl * g_vDiffuseColor.rgb * g_fSpecularScale;
}
	
float4 GetRefractionColor( float2 vScreenCoords, float4 fRefractAdjust, float4 vWorldPos, float fNdotV)
{
	float2 MaskRefract = fRefractAdjust.xy/vWorldPos.w + vScreenCoords;
	float fMasking = tex2D(samMaskingMap, MaskRefract).a;
	
	float2 ColorRefract = fRefractAdjust.xy/vWorldPos.w*fMasking + vScreenCoords;
	float4 RefractionColor = tex2D(samDiffuseMap, ColorRefract);
	
	float4 DepthColor = GetDepthColor( ColorRefract, vWorldPos.z); 	 	 	
	RefractionColor *= DepthColor;

	float ShoreScale= (1-DepthColor.a)*g_vShoreInfo.z;	//g_vShoreInfo.z = ShoreIntensity
	float2 vShoreTexcoord = (vWorldPos.xy + fRefractAdjust)*g_vShoreInfo.xy*0.01f;	//g_vShoreInfo.xy = UVScale
	float3 WaterShoreColor0 = tex2D(samWaterShore, vShoreTexcoord).rgb;
	float3 WaterShoreColor1 = tex2D(samWaterShore, vShoreTexcoord+float2(0.5,0.5f)).rgb;
	float3 WaterShoreColor = (WaterShoreColor0+WaterShoreColor1)*ShoreScale/2.0f;
	RefractionColor.rgb = RefractionColor.rgb+WaterShoreColor;	
	RefractionColor.a = pow(GetDepthColor( vScreenCoords, vWorldPos.z).a, g_vShoreInfo.w);	//g_vShoreInfo.w = Blending Power
	
	return RefractionColor;
}

float3 GetCubeMapCoord( float3 vWorldSpacePosition, float3 vWorldSpaceNormal )
{
 	float3 vView= normalize(vWorldSpacePosition - g_vCameraPos);
 	return reflect(vView, vWorldSpaceNormal);
}

float3 GetReflectionColor( float3 vWorldSpacePosition, float3 vWorldSpaceNormal )
{
	if(g_bUseReflectionMap)
		return g_vDiffuseColor.rgb 
			* texCUBE(samReflectCube, GetCubeMapCoord(vWorldSpacePosition, vWorldSpaceNormal).xzy ).rgb
			* g_fReflectAdjust;
	else
		return g_vDiffuseColor.rgb * g_fReflectAdjust;
}

void GetReflectionInfo( in SWaterOutput In, in float3 normalizedBump,
					   out float3 vReflectionColor, out float fFresnel )
{
	float3 vReflectNormal = normalize( lerp(In.vNormal,normalizedBump, g_fReflectionDistortion) );
 	
	vReflectionColor = GetReflectionColor(In.vWorldPos.xyz, vReflectNormal);
	fFresnel = GetFresnel(In.vCameraVec, vReflectNormal);
}

float3 ApplyReflection( float3 vSrcColor, float3 vReflectionColor, float fFresnel )
{
	return lerp(vSrcColor.rgb , vReflectionColor.rgb, fFresnel) *g_vWaterMaterial;
}

float4 WaterPlanePS( SWaterOutput In, float4 vPos : VPOS) : COLOR
{
	float3 bump = GetBump( In);
	float3 normalizedBump = normalize(bump);

	//카메라 각도에 따라 굴절 정도 조절. 비스듬히 볼 때 더 약하게.
	float fNdotV =dot(normalizedBump.rgb, In.vCameraVec);
	
	//Refract
	float4 fRefractAdjust = GetRefractAdjust( bump, In.vWorldPos.xyz, fNdotV);
	float4 RefractionColor = GetRefractionColor( vPos.xy / g_vResolution.xy + g_vResolution.zw, fRefractAdjust, In.vWorldPos, fNdotV);
	
	//Reflect
	float3 vReflectionColor =0;
	float fFresnel =0;
	GetReflectionInfo( In, normalizedBump, vReflectionColor, fFresnel);
	RefractionColor.rgb = ApplyReflection( RefractionColor.rgb, vReflectionColor, fFresnel );
	
	//reflection highlight
	RefractionColor.rgb += GetReflectionHighlight( normalizedBump.rgb, In.vCameraVec, fNdotV);
	
	//Apply fog
 	RefractionColor.rgb = lerp(g_vFogColor.rgb, RefractionColor.rgb, FogValue(In.vWorldPos.w));
 		
 	return RefractionColor;
}


// 뎁스 버퍼가 없을 시
float4 WaterPlaneLowPS( SWaterOutput In, float4 vPos : VPOS) : COLOR
{
	float3 bump = GetBump( In);
	float3 normalizedBump = normalize(bump);
	
	//카메라 각도에 따라 굴절 정도 조절. 비스듬히 볼 때 더 약하게.
	float fNdotV =dot(normalizedBump.rgb, normalize(In.vCameraVec));

	//Refract
	float4 RefractionColor = float4( g_fWaterRGBHalflife.rgb, 0.7f);

	//Reflect
 	float fresnel = GetFresnel(normalize(In.vCameraVec), normalizedBump);
 	float3 ReflectionColor = g_vDiffuseColor.rgb * g_fReflectAdjust.xxx;
 	
	RefractionColor.rgb = lerp(RefractionColor.rgb , ReflectionColor.rgb, fresnel.xxx) *g_vWaterMaterial;	
	
	//reflection highlight
	RefractionColor.rgb += GetReflectionHighlight( normalizedBump.rgb, In.vCameraVec, fNdotV).xxx;
 	
 	return RefractionColor;
}


float4 UnderWaterPlanePS( SWaterOutput In, float4 vPos : VPOS) : COLOR
{
	float3 bump = GetBump(In);
	float3 normalizedBump = normalize(bump);


	float2 vScreenCoords = vPos.xy / g_vResolution.xy + g_vResolution.zw;
	float2 Refract = bump.xy/In.vWorldPos.w * g_fBumpAdjustFactor * 20 + vScreenCoords.xy;
	float4 vResult = tex2D(samDiffuseMap, Refract);
 	vResult.a = 1.0f;


	//Reflect
	float3 vReflectionColor =0;
	float fFresnel =0;
	GetReflectionInfo( In, normalizedBump, vReflectionColor, fFresnel);
	vResult.rgb = ApplyReflection( vResult.rgb, vReflectionColor, 1-fFresnel );

 	return vResult;
}


float4 ProfilePS( SWaterOutput In , float4 vPos : VPOS) : COLOR
{
 	return float4(0.01f,0,0,1);
}


float4 MaskingVS(float3 vPosition	: POSITION) :POSITION
{
	SWaterOutput sOutput;
	
	float4 vFinalVertex;
	
	vFinalVertex.xyz = vPosition.xyz;
	vFinalVertex.w = 1.0f;


	//----------------------------------------------------------------------------
	// wave create
	
	//TODO: 현재 vDepth 값을 제대로 계산하지 않는다.
	//제대로 계산하게 되면 사용하자.
	float fDepthScale = 1;//tanh(vDepth/8000.0f);

	float fAmplitude =(g_fAmplitude1) * (fDepthScale);
	Wave wave[2] = {
		{ 0.15f, fAmplitude, g_fPhase1, float2(-1.0f, 0.0f) },
		{ 0.3f, fAmplitude/2.0f, g_fPhase1*2.6f, float2(-0.7f, 0.7f) },
	};

	float chopeness =2.0f;
	
	for(int i=0; i<2; i++) 
	{
    	vFinalVertex.z += evaluateWaveSharp(wave[i], vFinalVertex.xy /(g_fScale+0.0001f), g_fTime, chopeness)*g_fScale;
    }
    //----------------------------------------------------------------------------

  
	//result position
	return mul(vFinalVertex, g_mModelViewProj);			// project to screen
}

float4 MaskingPS() :COLOR
{
	return 1;
}


float4 RenderResultToScreenPS( float2 vTexcoord: TEXCOORD ) : COLOR
{
	float4 vColor = tex2D(samMaskingMap, vTexcoord);
	clip(sign(vColor.a)-1);	//Alpht Test
	
	return vColor;
}

///////////////////////////////////////////////////////////////////////  
//  Techniques

technique Water
{
    pass P0
    {         
        VertexShader = compile vs_3_0 WaterPlaneVS( );
        PixelShader = compile ps_3_0 WaterPlanePS( );
    }
}	

technique WaterLow
{
    pass P0
    {         
        VertexShader = compile vs_3_0 WaterPlaneVS( );
        PixelShader = compile ps_3_0 WaterPlaneLowPS( );
    }
}

technique UnderWater
{
    pass P0
    {          
        VertexShader = compile vs_3_0 WaterPlaneVS( );
        PixelShader = compile ps_3_0 UnderWaterPlanePS( );
    }
}

technique Masking
{
    pass P0
    {        
        VertexShader = compile vs_2_0 MaskingVS( );
        PixelShader = compile ps_2_0 MaskingPS( );
    }
}

technique RenderResultToScreen
{
    pass P0
    {        
        PixelShader = compile ps_2_0 RenderResultToScreenPS( );
    }
}

technique ProfileWater
{
    pass P0
    {          
        VertexShader = compile vs_3_0 WaterPlaneVS( );
        PixelShader = compile ps_3_0 ProfilePS( );
    }
}
