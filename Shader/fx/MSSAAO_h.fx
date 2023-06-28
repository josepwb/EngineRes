uniform float fWidth;
uniform float fHeight;
uniform float dMax = 100.f;
uniform float rMax = 7.5f;
uniform float3 	g_vFarClipCornerInView;
uniform float fFarZ;
uniform float fCalcRadius = 50.f;
uniform float fCalcDot = 0.65f;
uniform float fRawAOWeight = 2.65f;
// PS 내에서의 연산을 줄이기 위해 fReciprocalDist는 외부에서 연산 후 셋팅토록 한다.
uniform float fReciprocalDist = 1;		// 1.0f / ( g_fFalloffFar - g_fFalloffNear)
uniform float fFalloffNear = 1200.f;

#define dMaxSQ dMax * dMax


bool IsDiscard( float _fDepth )
{
	if( ( dMax / fFarZ  ) > abs( _fDepth )  )
		return true;
	return false;
}

float GetFactor( float _fDepth)
{
	float fFactor = 1;
  	// 포그 구하는 공식으로 일정 이상 거리에서는 AO를 처리 안하도록 하자
 	fFactor = 1 - saturate( ( _fDepth - fFalloffNear) * fReciprocalDist);
	return fFactor;
}

float2 GetStepSize( float _fPosZ, float fCount )
{
	float2 step_size = float2( rMax / fCount, rMax / fCount);
	return step_size;
}


float3 ReconstructPosFromDepth( float2 vScreencood, float _fDepth )
{
	float fDepth			= _fDepth;		
	fDepth					= abs(fDepth);
	float3 vRay;
	vRay.xy = lerp(-g_vFarClipCornerInView.xy, g_vFarClipCornerInView.xy, vScreencood);
	vRay.z = g_vFarClipCornerInView.z;
	vRay = float3( vRay * fDepth);
	vRay.z = -vRay.z;
	return vRay;
}


float3 ReconstructNormal( int nZDirection,  float2 vNormal )
{
	float3 vViewNormal =0;
	vViewNormal.xy = vNormal.xy;
	vViewNormal.z = sqrt( 1.0f - vViewNormal.x * vViewNormal.x - vViewNormal.y * vViewNormal.y ) * nZDirection;
	return vViewNormal;
}


void makeNormalDepthValue( sampler NormTex, sampler PosTex, in float2 tex, inout float3 depth, inout float3 Normal)
{
		depth.r = tex2Dlod( PosTex, float4(tex,0, 0) ).r;	
		
		int nZDirection = -1;
		[branch]
		if( 0 > depth.r )
			nZDirection = 1;
			
		depth = ReconstructPosFromDepth(tex,  depth.r);
		
		Normal.xy = tex2Dlod( NormTex, float4(tex,0, 0) ).xy;
		Normal	= ReconstructNormal( nZDirection, Normal.xy );
}


void ComputeOcclusion( sampler posTex, sampler maskTex, float2 xy, float3 normal, float3 pos, inout float occlusion, inout float sampleCount )
{		
	sampleCount += 1;
	
	float vDepthSpec	= tex2Dlod(posTex, float4( xy, 0, 0)).r;
		
	float3 vPosition			= ReconstructPosFromDepth( xy, vDepthSpec );
	float d = distance( pos.xyz, vPosition.xyz );	
	
	if( d > fCalcRadius )
		return;
	
	float t = min(1.0, (d * d) / ( dMaxSQ ));
	t = 1.f - t;	
			
	float3 diff = normalize( vPosition.xyz - pos.xyz );
	float cosTheta = max(dot( normal,  diff ), 0);
	
	if( cosTheta < fCalcDot )
		return;
	
	occlusion += t * cosTheta;
}


float3 Upsample( sampler loResNormTex, sampler loResPosTex, sampler loResAOTex, 
							float3 normal, float3 pos, float2 tex )
{	
	float2 loResCoord[4] = { float2(0, 0), float2(0, 0), float2(0, 0), float2(0, 0) };
	
	loResCoord[0] = tex.xy + float2( -1.f * fWidth, 1.f * fHeight );
	loResCoord[1] = tex.xy + float2( 1.f * fWidth, 1.f * fHeight );
	loResCoord[2] = tex.xy + float2( -1.f * fWidth, -1.f * fHeight);
	loResCoord[3] = tex.xy + float2( 1.f * fWidth, -1.f * fHeight );
	
	float3 loResAO[4]= { float3(0, 0, 0), float3(0, 0, 0), float3(0, 0, 0), float3(0, 0, 0) };
	for (int i = 0; i < 4; ++i)
	{
		loResAO[i]				= tex2D(loResAOTex, loResCoord[i]).xyz;
	}
		
	float totalWeight		= 0.f;
	float3 combinedAO	= 0.f;
	
	for (int i = 0; i < 4; ++i)
	{		
		float weight = 1;
		totalWeight += weight * fRawAOWeight;
		combinedAO += loResAO[i] * weight;
	}
	
	combinedAO /= totalWeight; 
	return combinedAO;
}