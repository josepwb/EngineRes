#line 1 "SpeedTreeFX.fx"

float4      m_avInstancePosition[ TREE_INSTAICING_SIZE];
float4      m_avInstanceData[ TREE_INSTAICING_SIZE];

float4x4	g_matViewProjection;
float4x4	g_matView;
float4x4	g_matWorld;

// wind
float       g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
float4x4    g_amWindMatrices[NUM_WIND_MATRICES];	// houses all of the wind matrices shared by all geometry types

// other
float3      g_vFogColor;							// fog color
float3      g_vFogParams;							// used for fog distance calcs: .x = fog start, .y = fog end, .z = end - start
float4      g_vTreeRotationTrig;					// stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)
float2      g_vCameraAngles;						// shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations
float4      g_vCameraAzimuthTrig;					// stores (sin, cos, -sin, 0.0) for the camera azimuth angle for optimized rotation in billboard vs

float2      g_vLightAngles;							// use for leaf vs shadow render

float		g_fAlphaRef = 0.33f;

float3		g_vLightDir;

float		g_fFarDist;

float		g_ShadowValue;

int			g_iUseNormalMap;

float3		g_vDiffuse;
float3		g_vAmbient;
float3		g_vSpecular;
float3		g_vEmissive;
float		g_fShiniss;


//int			g_iLowRT = 4;	// 외부 디파인으로 변경

#define c_fClearAlpha	(255.0f)                    // alpha testing, 255 means not visible
#define c_fOpaqueAlpha	(84.0f)                     // alpha testing, 84 means fully visible
#define c_fAlphaSpread	(171.0f)                    // 171 = 255 - 84
#define c_fTwoPi		(6.28318530f)               // 2 * pi

//-----------------------------------------------------
//Lighting 관련 상수
float4x4 g_ScreenspaceTransform;						//월드 공간의 점을 화면상의 좌표로 변환해주는 행렬


sampler samLightingMap : register(s8);			// M-Stage에서 라이트 맵으로 쓴다.
sampler samBranchDiffuseMap : register(s1);
sampler samBranchDetailMap : register(s5);
sampler samComposite : register(s0);			// composite billboard normal map
sampler samBillboardDiffuseMap : register(s3);	// composite billboard diffuse map
sampler samBillboardNormalMap : register(s4);	// composite billboard normal map
sampler samBranchNormalMap : register(s2);


////////////////////////////////////////////////////////////////////////////////////
// 사용하는 함수들

float FogValue(float fPoint)
{
	float fFogNear = g_vFogParams.x;
	float fFogFar = g_vFogParams.y;
	float fFogDist = g_vFogParams.z;
	// 0:포그없음 1:포그만땅
	return saturate( (fPoint - fFogNear) * fFogDist);
}

float Modulate_Float(float x, float y)
{
    return x - (int(x / y) * y);
}


float3 WindEffect(float3 vPosition, float2 vWindInfo)
{
    // decode both wind weights and matrix indices at the same time in order to save
    // vertex instructions
    vWindInfo.xy += g_fWindMatrixOffset.xx;
    float2 vWeights = frac(vWindInfo.xy);
    float2 vIndices = (vWindInfo - vWeights) * 0.05f * NUM_WIND_MATRICES;
    
    // first-level wind effect - interpolate between static position and fully-blown
    // wind position by the wind weight value
	float4 vPos = float4( vPosition.xyz, 1);
    float3 vWindEffect = lerp( vPosition.xyz, mul( g_amWindMatrices[int(vIndices.x)], vPos).xyz, vWeights.x);
    return vWindEffect;
}


///////////////////////////////////////////////////////////////////////  
//  RotationMatrix_zAxis
//
//  Constructs a Z-axis rotation matrix

float3x3 RotationMatrix_zAxis(float fAngle)
{
    // compute sin/cos of fAngle
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float3x3(vSinCos.y, -vSinCos.x, 0.0f, 
                    vSinCos.x, vSinCos.y, 0.0f, 
                    0.0f, 0.0f, 1.0f);
}


///////////////////////////////////////////////////////////////////////  
//  Rotate_zAxis
//
//  Returns an updated .xy value

float2 Rotate_zAxis(float fAngle, float3 vPoint)
{
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float2(dot(vSinCos.yx, vPoint.xy), dot(float2(-vSinCos.x, vSinCos.y), vPoint.xy));
}


///////////////////////////////////////////////////////////////////////  
//  RotationMatrix_yAxis
//
//  Constructs a Y-axis rotation matrix

float3x3 RotationMatrix_yAxis(float fAngle)
{
    // compute sin/cos of fAngle
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float3x3(vSinCos.y, 0.0f, vSinCos.x,
                    0.0f, 1.0f, 0.0f,
                    -vSinCos.x, 0.0f, vSinCos.y);
}


///////////////////////////////////////////////////////////////////////  
//  Rotate_yAxis
//
//  Returns an updated .xz value

float2 Rotate_yAxis(float fAngle, float3 vPoint)
{
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float2(dot(float2(vSinCos.y, -vSinCos.x), vPoint.xz), dot(vSinCos.xy, vPoint.xz));
}


///////////////////////////////////////////////////////////////////////  
//  RotationMatrix_xAxis
//
//  Constructs a X-axis rotation matrix

float3x3 RotationMatrix_xAxis(float fAngle)
{
    // compute sin/cos of fAngle
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float3x3(1.0f, 0.0f, 0.0f,
                    0.0f, vSinCos.y, -vSinCos.x,
                    0.0f, vSinCos.x, vSinCos.y);
}


///////////////////////////////////////////////////////////////////////  
//  Rotate_xAxis
//
//  Returns an updated .yz value

float2 Rotate_xAxis(float fAngle, float3 vPoint)
{
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float2(dot(vSinCos.yx, vPoint.yz), dot(float2(-vSinCos.x, vSinCos.y), vPoint.yz));
}



//----------------------------------------------------------------------------
// Calculate Billboard Depth-Offset (for problem of Self-Shadow)
float GetBillboardDepthOffset(float fBillboardSize, float fFarDist, float4 vColor)
{
	//Becase billboard color is commonly similar to green, use green-channel.
	float fDepthOffset = vColor.g -0.5f;		//	[0,1] => [-0.5,0.5]
	fDepthOffset *= fBillboardSize;

	return fDepthOffset;
}



////////////////////////////////////////////////////////////////////////////////////
// 줄기 쉐이더
////////////////////////////////////////////////////////////////////////////////////

float4      g_avLeafAngles[MAX_NUM_LEAF_ANGLES]; // each element: .x = rock angle, .y = rustle angle
                                                 // each element is a float4, even though only a float2 is needed, to facilitate
                                                 // fast uploads on all platforms (one call to upload whole array)
float4      g_vLeafAngleScalars;                 // each tree model has unique scalar values: .x = rock scalar, .y = rustle scalar



///////////////////////////////////////////////////////////////////////  
//  Billboard-specific global variables

// vs
float4      g_v360TexCoords[10];					// each element defines the texcoords for a single billboard image - each element has:
                                                     //     x = s-coord (rightmost s-coord of billboard)
                                                     //     y = t-coord (topmost t-coord of billboard) 
                                                     //     z = s-axis width (leftmost s-coord = x - z)
                                                     //     w = t-axis height (bottommost t-coord = y - w)
float       g_fSpecialAzimuth;                       // camera azimuth, adjusted to speed billboard vs computations
float4x4    g_amBBNormals;                           // all billboards share the same normals since they all face the camera
float4x4    g_amBBBinormals;                         // all billboards share the same binormals since they all face the camera  
float4x4    g_amBBTangents;                          // all billboards share the same tangents since they all face the camera
const float4x4    g_mBBUnitSquare =		// unit billboard card that's turned towards the camera.  card is aligned on 
{										// YZ plane and centered at (0.0f, 0.0f, 0.5f)
	float4(0.0f, 0.5f, 1.0f, 0.0f), 
	float4(0.0f, -0.5f, 1.0f, 0.0f), 
	float4(0.0f, -0.5f, 0.0f, 0.0f), 
	float4(0.0f, 0.5f, 0.0f, 0.0f) 
};
const float4x4    g_afTexCoordScales =	// used to compress & optimize the g_v360TexCoord lookups (x = s scale, y = t scale)
{ 
	float4(0.0f, 0.0f, 0.0f, 0.0f), 
	float4(1.0f, 0.0f, 0.0f, 0.0f), 
	float4(1.0f, 1.0f, 0.0f, 0.0f), 
	float4(0.0f, 1.0f, 0.0f, 0.0f) 
};
const float4x4    g_mLeafUnitSquare =	// unit leaf card that's turned towards the camera and wind-rocked/rustled by the
{										// vertex shader.  card is aligned on YZ plane and centered at (0.0f, 0.0f, 0.0f)
    float4(0.0f, 0.5f, 0.5f, 0.0f), 
    float4(0.0f, -0.5f, 0.5f, 0.0f), 
    float4(0.0f, -0.5f, -0.5f, 0.0f), 
    float4(0.0f, 0.5f, -0.5f, 0.0f)
};





//**************************************************************************************************************
// G-Stage


//----------------------------------------------------------------------
// 관련 구조체

struct GStageVSOutput
{
	float4 vPosition : POSITION;
	float2 vTexcoord : TEXCOORD0;
	float2 vDetail : TEXCOORD1;
	float4 vPositionInView : TEXCOORD2;
	float4 vNormal : TEXCOORD3;		// a : 알파 레퍼런스
	
	float3 vWPos		: TEXCOORD4;
	float3 vWorldNormal	: TEXCOORD5;
};

// 관련 구조체
//----------------------------------------------------------------------



//----------------------------------------------------------------------
// Vertex Shader

GStageVSOutput BranchGStageVS(	float4 inPosition			: POSITION,
								float4 inNormal				: NORMAL,
								float2 inWind				: TEXCOORD0,
								float2 inDetail				: TEXCOORD1,
								float  instanceIdx			: TEXCOORD4)
{
	GStageVSOutput Output = (GStageVSOutput)0;

	float2 inTexCoord = float2( inPosition.w, inNormal.w);
	inNormal.w = 0;
	float fAlphaRef = g_fAlphaRef;

	//Position
	float4 outPosition;
	outPosition.w = 1.0f;
	outPosition.xyz = inPosition;

	// 인스턴싱 사용 시: 마지막 두 인자를 사용
	{
		// 회전 적용
		outPosition.x = inPosition.x * m_avInstanceData[instanceIdx].z/*cos*/ + inPosition.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		outPosition.y = inPosition.y * m_avInstanceData[instanceIdx].z/*cos*/ - inPosition.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// Normal : 회전 적용
		float3 vNorm = inNormal;
		inNormal.x = vNorm.x * m_avInstanceData[instanceIdx].z/*cos*/ + vNorm.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		inNormal.y = vNorm.y * m_avInstanceData[instanceIdx].z/*cos*/ - vNorm.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// g_matWorld를 그대로 사용 하지 않고 변형 : 스케일링, 위치 적용
		g_matWorld[0] = float4( m_avInstanceData[instanceIdx].x, 0, 0, 0);
		g_matWorld[1] = float4( 0, m_avInstanceData[instanceIdx].x, 0, 0);
		g_matWorld[2] = float4( 0, 0, m_avInstanceData[instanceIdx].x, 0);
		g_matWorld[3] = float4( m_avInstancePosition[instanceIdx].xyz, 1);
		// 윈드 오프셋
		g_fWindMatrixOffset = m_avInstanceData[instanceIdx].w;
		// LOD 처리를 위해 알파 레퍼런스 값을 받아 옴.
		fAlphaRef = m_avInstancePosition[instanceIdx].w;
	}


	float4x4 matWorldViewProjection = mul( g_matWorld, g_matViewProjection);
	float4x4 matWorldView = mul( g_matWorld, g_matView);
	
	outPosition.xyz = WindEffect(outPosition.xyz, inWind);

	Output.vPosition = mul( outPosition, matWorldViewProjection );
	
	//Base Texcoord
	Output.vTexcoord = inTexCoord;
	Output.vDetail = inDetail;
	

	Output.vWorldNormal =  mul( inNormal, (float3x3)g_matWorld );
	Output.vWorldNormal =  normalize(Output.vWorldNormal);
	Output.vWPos = mul(outPosition, g_matWorld).xyz;
	
	//Normal
	//inNormal.xy = float2(dot(g_vTreeRotationTrig.yxw, inNormal.xyz), dot(g_vTreeRotationTrig.zyw, inNormal.xyz));
	// G스테이지에서는 노말이 뷰스페이스 기준이어야 한다.
    inNormal = mul( inNormal, matWorldView);
    Output.vNormal.xyz = inNormal;
    Output.vNormal.w = fAlphaRef;

	// for Depth
	Output.vPositionInView = mul( outPosition, matWorldView );
	
	
	return Output;
}


GStageVSOutput LeafCardGStageVS(	float4	vPosition			: POSITION,  // xyz = position, w = corner index
									float4	vNormal4			: NORMAL,
									float4	vTexCoord0			: TEXCOORD0, // xy = diffuse texcoords, zw = compressed wind parameters
									float4	vTexCoord1			: TEXCOORD1, // .x = width, .y = height, .z = pivot x, .w = pivot.y
									float4	vTexCoord2			: TEXCOORD2, // .x = angle.x, .y = angle.y, .z = wind angle index, .w = dimming
									float  instanceIdx			: TEXCOORD4)
								
{
	float3	vNormal = vNormal4;
	
    // this will be fed to the leaf pixel shader
    GStageVSOutput Output = (GStageVSOutput)0;
    
    // define attribute aliases for readability
    float fAzimuth = g_vCameraAngles.x;      // camera azimuth for billboarding
    float fPitch = g_vCameraAngles.y;        // camera pitch for billboarding
    float2 vSize = vTexCoord1.xy;            // leaf card width & height
    int nCorner = vPosition.w;               // which card corner this vertex represents [0,3]
    float fRotAngleX = vTexCoord2.x;         // angle offset for leaf rocking (helps make it distinct)
    float fRotAngleY = vTexCoord2.y;         // angle offset for leaf rustling (helps make it distinct)
    float fWindAngleIndex = vTexCoord2.z;    // which wind matrix this leaf card will follow
    float2 vPivotPoint = vTexCoord1.zw;      // point about which card will rock and rustle
    float2 vWindParams = vTexCoord0.zw;      // compressed wind parameters
    float fAlphaRef = g_fAlphaRef;

	// 인스턴싱 사용 시: 마지막 두 인자를 사용
	{
		// 위치 : 회전 적용
		float4 inPosition = vPosition;
		vPosition.x = inPosition.x * m_avInstanceData[instanceIdx].z/*cos*/ + inPosition.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vPosition.y = inPosition.y * m_avInstanceData[instanceIdx].z/*cos*/ - inPosition.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// 노말 : 회전 적용
		float3 inNormal = vNormal;
		vNormal.x = inNormal.x * m_avInstanceData[instanceIdx].z/*cos*/ + inNormal.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vNormal.y = inNormal.y * m_avInstanceData[instanceIdx].z/*cos*/ - inNormal.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// g_matWorld를 그대로 사용 하지 않고 변형 : 스케일링, 위치 적용
		g_matWorld[0] = float4( m_avInstanceData[instanceIdx].x, 0, 0, 0);
		g_matWorld[1] = float4( 0, m_avInstanceData[instanceIdx].x, 0, 0);
		g_matWorld[2] = float4( 0, 0, m_avInstanceData[instanceIdx].x, 0);
		g_matWorld[3] = float4( m_avInstancePosition[instanceIdx].xyz, 1);
		// 윈드 오프셋
		g_fWindMatrixOffset = m_avInstanceData[instanceIdx].w;
		// LOD 처리를 위해 알파 레퍼런스 값을 받아 옴.
		fAlphaRef = m_avInstancePosition[instanceIdx].w;
	}


    vPosition.xyz = WindEffect(vPosition.xyz, vWindParams);

    // compute rock and rustle values (all trees share the g_avLeafAngles table, but each can be scaled uniquely)
    float2 vLeafRockAndRustle = g_vLeafAngleScalars.xy * g_avLeafAngles[fWindAngleIndex].xy;;

    // access g_mLeafUnitSquare matrix with corner index and apply scales
    float3 vPivotedPoint = g_mLeafUnitSquare[nCorner].xyz;

    // adjust by pivot point so rotation occurs around the correct point
    vPivotedPoint.yz += vPivotPoint;
    float3 vCorner = vPivotedPoint * vSize.xxy;

    // rock & rustling on the card corner
    float3x3 matRotation = RotationMatrix_zAxis(fAzimuth + fRotAngleX);
    matRotation = mul(matRotation, RotationMatrix_yAxis(fPitch + fRotAngleY));
    matRotation = mul(matRotation, RotationMatrix_zAxis(vLeafRockAndRustle.y));
    matRotation = mul(matRotation, RotationMatrix_xAxis(vLeafRockAndRustle.x));
    
    vCorner = mul(matRotation, vCorner);
    
    // place and scale the leaf card
    vPosition.xyz += vCorner;
    vPosition.w = 1.0f;
    
	float4x4 matWorldViewProjection = mul( g_matWorld, g_matViewProjection);
    Output.vPosition = mul( vPosition, matWorldViewProjection );
	
	//Base Texcoord
	Output.vTexcoord = vTexCoord0.xy;
	
	// G스테이지에서는 노말을 뷰스페이스 기준이어야 한다.
	// 빌보딩이니까 값이 일정하게 나와야 할 것 같지만, 나무 하나를 원통 기준의 노말로 사용 되져서 셰이딩을 하는 것 같다.
	float4x4 matWorldView = mul( g_matWorld, g_matView );
	vNormal = mul( vNormal, (float3x3)matWorldView );
    vNormal = normalize( vNormal);
	Output.vNormal.xyz = vNormal;
	Output.vNormal.w = fAlphaRef;

	
	float4 vPosInView = mul(vPosition, matWorldView);
	Output.vPositionInView = float4(vPosInView.z, g_fFarDist, g_fFarDist, vSize.y);
		
	return Output;
}



GStageVSOutput LeafMeshGStageVS(	float4	vPosition			: POSITION,   // xyz = position, w = compressed wind param 1
									float4	vNormal4			: NORMAL,     // xyz = normal xyz
									float4	vTexCoord0			: TEXCOORD0,  // xy = diffuse texcoords, z = wind angle index, w = dimming
									float4	vOrientX4			: TEXCOORD1,  // xyz = vector xyz
									float2	vOrientZ2			: TEXCOORD2,  // xyz = vector xyz
									float4	vOffset				: TEXCOORD3,  // xyz = mesh placement position, w = compressed wind param 2
									float  instanceIdx			: TEXCOORD4)
{
	float3	vNormal = vNormal4;
	float3	vOrientX = float3(vOrientX4.x, vOrientX4.y, vOrientX4.z);
	float3	vOrientZ = float3(vOrientX4.w, vOrientZ2.x, vOrientZ2.y);
									
    // this will be fed to the leaf pixel shader
    GStageVSOutput Output = (GStageVSOutput)0;
    
    // define attribute aliases for readability
    float fWindAngleIndex = vTexCoord0.z;       // which wind matrix this leaf card will follow
    float2 vWindParams = float2(vPosition.w, vOffset.w);
    
   
    // compute rock and rustle values (all trees share the g_avLeafAngles table), but g_vLeafAngleScalars
    // scales the angles to match wind settings specified in SpeedTreeCAD
    float2 vLeafRockAndRustle = g_vLeafAngleScalars.xy * g_avLeafAngles[fWindAngleIndex].xy;
    
    // vPosition stores the leaf mesh geometry, not yet put into place at position vOffset.
    // leaf meshes rock and rustle, which requires rotations on two axes (rustling is not
    // useful on leaf mesh geometry)
    float3x3 matRockRustle = RotationMatrix_xAxis(vLeafRockAndRustle.x); // rock
    vPosition.xyz = mul(matRockRustle, vPosition.xyz);
    
    // build mesh orientation matrix - cannot be done beforehand on CPU due to wind effect / rotation order issues.
    // it is used to orient each mesh into place at vOffset

    float3 vOrientY = cross(vOrientX, vOrientZ);
    

    float3x3 matOrientMesh =
    {
        vOrientX, vOrientY, vOrientZ
    };
    
    // apply orientation matrix to the mesh positon & normal
    vPosition.xyz = mul(matOrientMesh, vPosition.xyz);
    //Normal
    vNormal.xyz = mul(matOrientMesh, vNormal.xyz);
	
	// 인스턴싱 사용 시: 마지막 두 인자를 사용
	{
		// 위치 : 회전 적용
		float4 inPosition = vPosition;
		vPosition.x = inPosition.x * m_avInstanceData[instanceIdx].z/*cos*/ + inPosition.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vPosition.y = inPosition.y * m_avInstanceData[instanceIdx].z/*cos*/ - inPosition.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// 오프셋 : 회전 적용
		float4 inOffset = vOffset;
		vOffset.x = inOffset.x * m_avInstanceData[instanceIdx].z/*cos*/ + inOffset.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vOffset.y = inOffset.y * m_avInstanceData[instanceIdx].z/*cos*/ - inOffset.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// 노말 : 회전 적용
		float3 inNormal = vNormal;
		vNormal.x = inNormal.x * m_avInstanceData[instanceIdx].z/*cos*/ + inNormal.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vNormal.y = inNormal.y * m_avInstanceData[instanceIdx].z/*cos*/ - inNormal.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// g_matWorld를 그대로 사용 하지 않고 변형 : 스케일링, 위치 적용
		g_matWorld[0] = float4( m_avInstanceData[instanceIdx].x, 0, 0, 0);
		g_matWorld[1] = float4( 0, m_avInstanceData[instanceIdx].x, 0, 0);
		g_matWorld[2] = float4( 0, 0, m_avInstanceData[instanceIdx].x, 0);
		g_matWorld[3] = float4( m_avInstancePosition[instanceIdx].xyz, 1);
		// 윈드 오프셋
		g_fWindMatrixOffset = m_avInstanceData[instanceIdx].w;
	}


	float4x4 matWorldViewProjection = mul( g_matWorld, g_matViewProjection);
	
	// and has the wind effect motion applied to it
	vOffset.xyz = WindEffect(vOffset.xyz, vWindParams);
    // put oriented mesh into place at rotated and wind-affected vOffset
	vPosition.xyz += vOffset.xyz;

	float4 outPosition = vPosition;
	outPosition.w = 1.0f;
	Output.vPosition = mul(outPosition, matWorldViewProjection);

	vNormal = normalize( vNormal);
    Output.vNormal.xyz = vNormal;
    Output.vNormal.w = g_fAlphaRef;

	//Base TextureCoord
    Output.vTexcoord = vTexCoord0.xy;

    // for depth
	float4x4 matWorldView = mul(g_matWorld, g_matView);
	Output.vPositionInView = mul(outPosition, matWorldView);
    
    return Output;
}

// Vertex Shader
//----------------------------------------------------------------------





///////////////////////////////////////////////////////////////////////  
//  Billboard1VS
//
//  In order to ensure smooth LOD transitions, two billboards are rendered
//  per tree instance.  Each billboard represents a partially faded rendering
//  of the two closest billboard images for the current camera azimuth and
//  current tree instance rotation.
//
//  Separate shaders are necessary because since different equations are used
//  to pick the billboard index and fade values for the two bb's.

GStageVSOutput Billboard1VSGStage(	float4 vPosition      : POSITION,     // xyz = position, w = corner index
								    float4 vGeom          : TEXCOORD0,    // x = width, y = height, z = tree azimuth, w = lod fade
									float4 vMiscParams    : TEXCOORD1,    // x = scale, y = texcoord offset, z = num images, w = 360 transition %
									float3 vLightAdjusts  : TEXCOORD2)    // x = bright side adjustment, y = dark side adjustment, z = ambient scale
{
    //global float4 g_v360TexCoords[NUM_360_IMAGES];
    
    // this will be fed to the frond pixel shader
    GStageVSOutput sOutput = (GStageVSOutput)0;
    
    // define attribute aliases for readability
    float fAzimuth = g_vCameraAngles.x;         // current camera azimuth
    float fPitch = g_vCameraAngles.y;           // current camera pitch
    int nCorner = vPosition.w;                  // which card corner this vertex represents [0,3]
    int nNumImages = vMiscParams.z;             // # of 360-degree images
    float c_fSliceDiameter = c_fTwoPi / float(nNumImages); // diameter = 360 / g_nNum360Images
    float c_fLodFade = vGeom.w;                 // computed on CPU - the amount the billboard as a whole is faded from 3D geometry
    float c_fTreeScale = vMiscParams.x;         // uniform scale of tree instance
    float c_fTransitionPercentage = vMiscParams.w;  // controls how thick or thin the 360-degree image transition is 
    int nTexCoordTableOffset = vMiscParams.y;   // offset into g_v360TexCoords where this instance's texcoords begin
    
    // there are two azimuth values to consider:
    //    1) fAzimuth: the azimuth of the camera position
    //    2) fAdjustedAzimuth: the azimuth of the camera plus the orientation of the tree the billboard 
    //                         represents (used to determine which bb image to use and its alpha value)
    
    // modify the adjusted azimuth to appear in range [0,2*pi]
    float fAdjustedAzimuth = g_fSpecialAzimuth - vGeom.z;
    if (fAdjustedAzimuth < 0.0f)
        fAdjustedAzimuth += c_fTwoPi;
    if (fAdjustedAzimuth > c_fTwoPi)
        fAdjustedAzimuth -= c_fTwoPi;
        
    // pick the billboard image index and access the extract texcoords from the table
    int nIndex0 = int(fAdjustedAzimuth / c_fSliceDiameter);
    if (nIndex0 > nNumImages - 1)
        nIndex0 = 0;

    // compute the alpha fade value
	float fAlpha0 = (fAdjustedAzimuth - (nIndex0 * c_fSliceDiameter)) / c_fSliceDiameter;

    float fFadePoint = lerp(c_fClearAlpha, c_fOpaqueAlpha, c_fLodFade);
    
    // 4.1 (helps reduce a too-faded look)
    fAlpha0 = max(fAlpha0, c_fTransitionPercentage);
    //  warning X3571: pow(f, e) will not work for negative f, use abs(f) or conditionally handle negative values if you expect them. so must saturate
    fAlpha0 = lerp(fFadePoint, c_fClearAlpha, pow( saturate((fAlpha0 - c_fTransitionPercentage) / (1.0f - c_fTransitionPercentage)), 1.7f));
    
    // each billboard may be faded at a distinct value, but it isn't efficient to change
    // the alpha test value per billboard.  instead we adjust the alpha value of the 
    // billboards's outgoing color to achieve the same effect against a static alpha test 
    // value (c_gOpaqueAlpha).
    fAlpha0 = 1.0f - (fAlpha0 - c_fOpaqueAlpha) / c_fAlphaSpread;

    // multiply by the correct corner
    float3 vecCorner = g_mBBUnitSquare[nCorner].xyz * vGeom.xxy * c_fTreeScale;

    // apply rotation to scaled corner
    vecCorner.xy = float2(dot(g_vCameraAzimuthTrig.yxw, vecCorner.xyz), dot(g_vCameraAzimuthTrig.zyw, vecCorner.xyz));

    vPosition.xyz += vecCorner;
    vPosition.w = 1.0f;

    // project to the screen
	sOutput.vPosition = mul(vPosition, g_matViewProjection);
    sOutput.vNormal.x = fAlpha0;

	float4x4 matWorldView = mul( g_matWorld, g_matView);
	sOutput.vPositionInView = mul(vPosition, g_matView);

    // determine texcoords based on corner position - while not a straighforward method for determining the texcoords
    // for a specific corner, this one provided a good compromise of speed and space
    float4 vTexCoords = g_v360TexCoords[nIndex0 + nTexCoordTableOffset];
    sOutput.vTexcoord.x = vTexCoords.x - vTexCoords.z * g_afTexCoordScales[nCorner].x;
    sOutput.vTexcoord.y = vTexCoords.y - vTexCoords.w * g_afTexCoordScales[nCorner].y;
    
    return sOutput;
}



GStageVSOutput Billboard2VSGStage(	float4 vPosition      : POSITION,     // xyz = position, w = corner index
									float4 vGeom          : TEXCOORD0,    // x = width, y = height, z = tree azimuth, w = lod fade
									float4 vMiscParams    : TEXCOORD1,    // x = scale, y = texcoord offset, z = num images, w = 360 transition %
									float3 vLightAdjusts  : TEXCOORD2)    // x = bright side adjustment, y = dark side adjustment, z = ambient scale
{
    // this will be fed to the frond pixel shader
    GStageVSOutput sOutput = (GStageVSOutput)0;
    
    // define attribute aliases for readability
    float fAzimuth = g_vCameraAngles.x;         // current camera azimuth
    float fPitch = g_vCameraAngles.y;           // current camera pitch
    int nCorner = vPosition.w;                  // which card corner this vertex represents [0,3]
    int nNumImages = vMiscParams.z;             // # of 360-degree images
    float c_fSliceDiameter = c_fTwoPi / float(nNumImages); // diameter = 360 / g_nNum360Images
    float c_fLodFade = vGeom.w;                 // computed on CPU - the amount the billboard as a whole is faded from 3D geometry
    float c_fTreeScale = vMiscParams.x;         // uniform scale of tree instance
    float c_fTransitionPercentage = vMiscParams.w;  // controls how thick or thin the 360-degree image transition is 
    int nTexCoordTableOffset = vMiscParams.y;   // offset into g_v360TexCoords where this instance's texcoords begin
    
    // there are two azimuth values to consider:
    //    1) fAzimuth: the azimuth of the camera position
    //    2) fAdjustedAzimuth: the azimuth of the camera plus the orientation of the tree the billboard 
    //                         represents (used to determine which bb image to use and its alpha value)

    // modify the adjusted azimuth to appear in range [0,2*pi]
    float fAdjustedAzimuth = g_fSpecialAzimuth - vGeom.z;
    if (fAdjustedAzimuth < 0.0f)
        fAdjustedAzimuth += c_fTwoPi;
    if (fAdjustedAzimuth > c_fTwoPi)
        fAdjustedAzimuth -= c_fTwoPi;
            
    // pick the index and access the texcoords
//  int nIndex1 = int(fAdjustedAzimuth / c_fSliceDiameter);
	int nIndex1 = int(fAdjustedAzimuth / c_fSliceDiameter + 1);
    if (nIndex1 > nNumImages - 1)
        nIndex1 = 0;
    
    // compute the alpha fade value
	float fAlpha1 = 1.0f - Modulate_Float(fAdjustedAzimuth, c_fSliceDiameter) / c_fSliceDiameter;

    float fFadePoint = lerp(c_fClearAlpha, c_fOpaqueAlpha, c_fLodFade);
    
    // 4.1 (helps reduce a too-faded look)
    fAlpha1 = max(fAlpha1, c_fTransitionPercentage);
    //  warning X3571: pow(f, e) will not work for negative f, use abs(f) or conditionally handle negative values if you expect them. so must saturate
    fAlpha1 = lerp(fFadePoint, c_fClearAlpha, pow( saturate((fAlpha1 - c_fTransitionPercentage) / (1.0f - c_fTransitionPercentage)), 1.7f));
    
    // each billboard may be faded at a distinct value, but it isn't efficient to change
    // the alpha test value per billboard.  instead we adjust the alpha value of the 
    // billboards's outgoing color to achieve the same effect against a static alpha test 
    // value (c_gOpaqueAlpha).
    fAlpha1 = 1.0f - (fAlpha1 - c_fOpaqueAlpha) / c_fAlphaSpread;

    // multiply by the correct corner
    float3 vecCorner = g_mBBUnitSquare[nCorner].xyz * vGeom.xxy * c_fTreeScale;

    // apply rotation to scaled corner
    vecCorner.xy = float2(dot(g_vCameraAzimuthTrig.yxw, vecCorner.xyz), dot(g_vCameraAzimuthTrig.zyw, vecCorner.xyz));
    vPosition.xyz += vecCorner;
    vPosition.w = 1.0f;
    
	// project to the screen
	sOutput.vPosition = mul(vPosition, g_matViewProjection);
    sOutput.vNormal.x = fAlpha1;
	
	float4x4 matWorldView = mul( g_matWorld, g_matView);
	sOutput.vPositionInView = mul(vPosition, g_matView);
	
	// determine texcoords based on corner position - while not a straighforward method for determining the texcoords
    // for a specific corner, this one provided a good compromise of speed and space
    float4 vTexCoords = g_v360TexCoords[nIndex1 + nTexCoordTableOffset];
    sOutput.vTexcoord.x = vTexCoords.x - vTexCoords.z * g_afTexCoordScales[nCorner].x;
    sOutput.vTexcoord.y = vTexCoords.y - vTexCoords.w * g_afTexCoordScales[nCorner].y; 
    
    return sOutput;
}	

// G-Stage
//**************************************************************************************************************















// Deferred
//**************************************************************************************************************

//----------------------------------------------------------------------
// Pixel Shader

struct PSOUTPUT_DEFERRED {
	float4 color  : COLOR0;
#if g_iLowRT > 1
	float4 color1 : COLOR1;
#endif
#if g_iLowRT > 2
	float4 color2 : COLOR2;
#endif
};

float4 GetDeferredDiffuse(sampler sSampler, float2 vTexcoord, float fAlphaRef)
{
	float4 texDiffuse = tex2D(sSampler, vTexcoord);
	float fAlpha = texDiffuse.a;

	clip( fAlpha - fAlphaRef);

	float fDontAO = 1;

	// a 채널에는 AO 마스킹
	return float4(texDiffuse.rgb, fDontAO);
}

float4 GetDeferredDiffuseWithAlphaFactor(sampler sSampler, float2 vTexcoord, float fAlphaRef, float fAlphaFactor)
{
	float4 texDiffuse = tex2D(sSampler, vTexcoord);
	float fAlpha = texDiffuse.a *fAlphaFactor;

	clip( fAlpha - fAlphaRef);

	float fDontAO = 1;

	// a 채널에는 AO 마스킹
	return float4(texDiffuse.rgb, fDontAO);
}

float4 GetDeferredDiffuseWithDetail(sampler sSampler, float2 vTexcoord, sampler sDetailSampler, float2 vDetailTexcoord, float fAlphaRef)
{
	float4 texDiffuse = GetDeferredDiffuse(sSampler, vTexcoord, fAlphaRef);

	texDiffuse.rgb = g_vDiffuse * texDiffuse.rgb;

	float4 texDetail = tex2D(sDetailSampler, vDetailTexcoord);
	texDiffuse.rgb = lerp(texDiffuse.rgb, texDetail.rgb, texDetail.a); 

	return texDiffuse;
}

float4 GetDeferredNormal(float3 vNormal)
{
	// 노말은 xy 두개의 값만 기록하고 사용 시 z는 추측해내서 쓴다.
	return float4( vNormal.x, vNormal.y, 1, 1);
}

float4 GetDeferredDepth(float fViewSpaceDepth, float fFarDistance)
{
	// Linear-Depth 기록. 스페큘라 림 부분은 안먹게 0으로 설정
	return float4( -fViewSpaceDepth/fFarDistance, 0, 1, 1);
}

float4 GetDeferredDepthTest(float fViewSpaceDepth, float fFarDistance, float NormalZ)
{
	// Linear-Depth 기록. 스페큘라 림 부분은 안먹게 0으로 설정
	int nZDirection = (sign(NormalZ)>=0)*2-1;
	return float4( (-(fViewSpaceDepth/fFarDistance)) * nZDirection, 0, 1, 1);
}


float4 GetDeferredLeafCardDepth(float fViewSpaceDepth, float fFarDistance, float fBillboardsize, float4 vColor, float NormalZ)
{
	// Apply offset for Self-Shadow problem...
	float fDepthOffset = GetBillboardDepthOffset(fBillboardsize, fFarDistance, vColor);
	int nZDirection = (sign(NormalZ)>=0)*2-1;
	return float4( (-(fViewSpaceDepth+fDepthOffset)/fFarDistance) * nZDirection , 0, 1, 1);
}


PSOUTPUT_DEFERRED DeferredPS(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;
	
#if g_iLowRT <= 1
	output.color	= GetDeferredDiffuse(samComposite, Input.vTexcoord.xy, g_fAlphaRef);

#elif g_iLowRT == 2
	output.color	= GetDeferredNormal(normalize(Input.vNormal.xyz));
	output.color1	= GetDeferredDiffuse(samComposite, Input.vTexcoord.xy, g_fAlphaRef);

#elif g_iLowRT == 3
	output.color	= GetDeferredNormal(normalize(Input.vNormal.xyz));
	output.color1	= GetDeferredDepth(Input.vPositionInView.z, g_fFarDist);
	output.color2	= GetDeferredDiffuse(samComposite, Input.vTexcoord.xy, g_fAlphaRef);
#endif

	return output;
}


float3x3 invert_3x3_nodet( float3x3 M )
{
	float3x3 T = transpose( M );	

	return float3x3(
		cross( T[1], T[2] ),
		cross( T[2], T[0] ),
		cross( T[0], T[1] ) );	
}


float3x3 invert_3x3( float3x3 M )
{
	float det = dot( cross(M[0], M[1] ), M[2] );
	float3x3 T = transpose( M );
	return float3x3( cross ( T[1], T[2] ), cross( T[2], T[0] ), cross( T[0] , T[1] ) ) / det;
}

void CalcNormalMapBasedNormal( inout float3 _vNormal, in float4 _vNormalColor, in float3 _vWPos, in float2 _vForNormalMapTex, in float3 _vWordlViewNormal )
{
	_vNormalColor = 2.f * _vNormalColor - 1.f;
	_vNormalColor = normalize(_vNormalColor);
	
	float3 dPdx		= ddx( _vWPos );
	float3 dPdy		= ddy( _vWPos );
	float2 dUVdx	= ddx(_vForNormalMapTex);
	float2 dUVdy	= ddy(_vForNormalMapTex);
	
	float3x3 M = float3x3( dPdx, dPdy, cross( dPdx, dPdy ) );
	float3x3 inverseM = invert_3x3_nodet( M );
	float3 B = mul( inverseM, float3( dPdx.x, dPdy.x, 0 ) );
	float3 T = mul( inverseM, float3( dPdx.y, dPdy.y, 0 ) );
	
	float maxLength = max( length( T ), length( B ) );
	
	float3x3 finalM = float3x3( T / maxLength, B / maxLength, _vWordlViewNormal );
	_vNormal = normalize( mul( _vNormalColor, finalM ) );

	float4x4 matWorldView = g_matView;
	
	_vNormal = mul( _vNormal, (float3x3)matWorldView).xyz;
	_vNormal = normalize(_vNormal);

}


PSOUTPUT_DEFERRED DeferredBranchPS(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;
	
	float3 vNomal = normalize(Input.vNormal.xyz);
	if( 1 == g_iUseNormalMap )
	{
		float4 vNormalColor = tex2D(samBranchNormalMap, Input.vTexcoord);
		vNomal = normalize(Input.vNormal.xyz);
		CalcNormalMapBasedNormal( vNomal, vNormalColor, Input.vWPos, Input.vTexcoord, Input.vWorldNormal );
	}
		
#if g_iLowRT <= 1
	output.color	= GetDeferredDiffuseWithDetail(samBranchDiffuseMap, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 2
	output.color	= GetDeferredNormal(normalize( vNomal ));
	output.color1	= GetDeferredDiffuseWithDetail(samBranchDiffuseMap, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 3
		
	output.color	= GetDeferredNormal( vNomal );
	output.color1	= GetDeferredDepthTest(Input.vPositionInView.z, g_fFarDist, vNomal.z);
	output.color2	= GetDeferredDiffuseWithDetail(samBranchDiffuseMap, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);
#endif

	return output;
}


PSOUTPUT_DEFERRED LeafCardDeferredPS(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;
	
	
#if g_iLowRT <= 1
	output.color	= GetDeferredDiffuseWithDetail(samComposite, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 2
	output.color	= GetDeferredNormal( normalize(Input.vNormal.xyz) );
	output.color1	= GetDeferredDiffuseWithDetail(samComposite, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 3
	output.color	= GetDeferredNormal( normalize(Input.vNormal.xyz) );
	output.color2	= GetDeferredDiffuseWithDetail(samComposite, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);
	output.color1	= GetDeferredLeafCardDepth(Input.vPositionInView.x, Input.vPositionInView.y, Input.vPositionInView.a, output.color2, normalize(Input.vNormal.z));	
#endif

	return output;
}


PSOUTPUT_DEFERRED BillboardPSDeferred(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;

#if g_iLowRT <= 1
	output.color = GetDeferredDiffuseWithAlphaFactor(samBillboardDiffuseMap, Input.vTexcoord, g_fAlphaRef, Input.vNormal.x);

#elif g_iLowRT == 2
	output.color = GetDeferredNormal( tex2D(samBillboardNormalMap, Input.vTexcoord.xy).xyz );
	output.color1 = GetDeferredDiffuseWithAlphaFactor(samBillboardDiffuseMap, Input.vTexcoord, g_fAlphaRef, Input.vNormal.x);

#elif g_iLowRT == 3
	output.color = GetDeferredNormal( tex2D(samBillboardNormalMap, Input.vTexcoord.xy).xyz );
	output.color1 = GetDeferredDepth(Input.vPositionInView.z, g_fFarDist);
	output.color2 = GetDeferredDiffuseWithAlphaFactor(samBillboardDiffuseMap, Input.vTexcoord, g_fAlphaRef, Input.vNormal.x);
#endif

    return output;
}

//----------------------------------------------------------------------
// Technique

technique BranchDeferred
{
    pass P0
    {          
        VertexShader = compile vs_3_0 BranchGStageVS();
        PixelShader = compile ps_3_0 DeferredBranchPS();
    }
}

technique FrondDeferred
{
	pass P0
	{
		VertexShader = compile vs_3_0 BranchGStageVS();
		PixelShader = compile ps_3_0 DeferredPS();
	}
}

technique LeafCardDeferred
{
    pass P0
    {
        VertexShader = compile vs_3_0 LeafCardGStageVS();
        PixelShader = compile ps_3_0 LeafCardDeferredPS();
    }
}

technique LeafMeshDeferred
{
    pass P0
    {
		VertexShader = compile vs_3_0 LeafMeshGStageVS();
        PixelShader = compile ps_3_0 DeferredPS();
    }
}

technique BillboardDeferred
{
    pass P0
    {          
        VertexShader = compile vs_3_0 Billboard1VSGStage();
        PixelShader = compile ps_3_0 BillboardPSDeferred();
    }
	pass P1
	{
        VertexShader = compile vs_3_0 Billboard2VSGStage();
        PixelShader = compile ps_3_0 BillboardPSDeferred();
	}
}

// Profile Technique
//----------------------------------------------------------------------
PSOUTPUT_DEFERRED DeferredProfileBranchPS(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;
	
	float3 vNomal = normalize(Input.vNormal.xyz);
	if( 1 == g_iUseNormalMap )
	{
		float4 vNormalColor = tex2D(samBranchNormalMap, Input.vTexcoord);
		vNomal = normalize(Input.vNormal.xyz);
		CalcNormalMapBasedNormal( vNomal, vNormalColor, Input.vWPos, Input.vTexcoord, Input.vWorldNormal );
	}
		
#if g_iLowRT <= 1
	output.color	= GetDeferredDiffuseWithDetail(samBranchDiffuseMap, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 2
	output.color	= GetDeferredNormal(normalize( vNomal ));
	output.color1	= GetDeferredDiffuseWithDetail(samBranchDiffuseMap, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 3
		
	output.color	= GetDeferredNormal( vNomal );
	output.color1	= GetDeferredDepthTest(Input.vPositionInView.z, g_fFarDist, vNomal.z);
	output.color2	= GetDeferredDiffuseWithDetail(samBranchDiffuseMap, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);
#endif

	output.color = float4(0.01f, 0 , 0, 1);
    return output;
}


PSOUTPUT_DEFERRED DeferredProfilePS(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;
	
#if g_iLowRT <= 1
	output.color	= GetDeferredDiffuse(samComposite, Input.vTexcoord.xy, g_fAlphaRef);

#elif g_iLowRT == 2
	output.color	= GetDeferredNormal(normalize(Input.vNormal.xyz));
	output.color1	= GetDeferredDiffuse(samComposite, Input.vTexcoord.xy, g_fAlphaRef);

#elif g_iLowRT == 3
	output.color	= GetDeferredNormal(normalize(Input.vNormal.xyz));
	output.color1	= GetDeferredDepth(Input.vPositionInView.z, g_fFarDist);
	output.color2	= GetDeferredDiffuse(samComposite, Input.vTexcoord.xy, g_fAlphaRef);
#endif
	output.color = float4(0.01f, 0 , 0, 1);
    return output;
}

PSOUTPUT_DEFERRED LeafCardProfileDeferredPS(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;
	
	
#if g_iLowRT <= 1
	output.color	= GetDeferredDiffuseWithDetail(samComposite, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 2
	output.color	= GetDeferredNormal( normalize(Input.vNormal.xyz) );
	output.color1	= GetDeferredDiffuseWithDetail(samComposite, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);

#elif g_iLowRT == 3
	output.color	= GetDeferredNormal( normalize(Input.vNormal.xyz) );
	output.color2	= GetDeferredDiffuseWithDetail(samComposite, Input.vTexcoord, samBranchDetailMap, Input.vDetail, Input.vNormal.a);
	output.color1	= GetDeferredLeafCardDepth(Input.vPositionInView.x, Input.vPositionInView.y, Input.vPositionInView.a, output.color2, normalize(Input.vNormal.z));	
#endif

	output.color = float4(0.01f, 0 , 0, 1);
    return output;
}

PSOUTPUT_DEFERRED BillboardProfilePSDeferred(GStageVSOutput Input)
{
	PSOUTPUT_DEFERRED output = (PSOUTPUT_DEFERRED)0;

#if g_iLowRT <= 1
	output.color = GetDeferredDiffuseWithAlphaFactor(samBillboardDiffuseMap, Input.vTexcoord, g_fAlphaRef, Input.vNormal.x);

#elif g_iLowRT == 2
	output.color = GetDeferredNormal( tex2D(samBillboardNormalMap, Input.vTexcoord.xy).xyz );
	output.color1 = GetDeferredDiffuseWithAlphaFactor(samBillboardDiffuseMap, Input.vTexcoord, g_fAlphaRef, Input.vNormal.x);

#elif g_iLowRT == 3
	output.color = GetDeferredNormal( tex2D(samBillboardNormalMap, Input.vTexcoord.xy).xyz );
	output.color1 = GetDeferredDepth(Input.vPositionInView.z, g_fFarDist);
	output.color2 = GetDeferredDiffuseWithAlphaFactor(samBillboardDiffuseMap, Input.vTexcoord, g_fAlphaRef, Input.vNormal.x);
#endif

	output.color = float4(0.01f, 0 , 0, 1);
    return output;
}

technique BranchProfileDeferred
{
    pass P0
    {          
        VertexShader = compile vs_3_0 BranchGStageVS();
        PixelShader = compile ps_3_0 DeferredProfileBranchPS();
    }
}

technique FrondProfileDeferred
{
	pass P0
	{
		VertexShader = compile vs_3_0 BranchGStageVS();
		PixelShader = compile ps_3_0 DeferredProfilePS();
	}
}

technique LeafCardProfileDeferred
{
    pass P0
    {
        VertexShader = compile vs_3_0 LeafCardGStageVS();
        PixelShader = compile ps_3_0 LeafCardProfileDeferredPS();
    }
}

technique LeafMeshProfileDeferred
{
    pass P0
    {
		VertexShader = compile vs_3_0 LeafMeshGStageVS();
        PixelShader = compile ps_3_0 DeferredProfilePS();
    }
}

technique BillboardProfileDeferred
{
    pass P0
    {          
        VertexShader = compile vs_3_0 Billboard1VSGStage();
        PixelShader = compile ps_3_0 BillboardProfilePSDeferred();
    }
	pass P1
	{
        VertexShader = compile vs_3_0 Billboard2VSGStage();
        PixelShader = compile ps_3_0 BillboardProfilePSDeferred();
	}
}






//////////////// shadow map 을 위한 것들

//float3		g_omniLightPos;
//float		g_fOmniLightAttnEnd;

struct DepthOutVertexShadow
{
    float4 vPosition      : POSITION;
    float2 vBaseTexCoords : TEXCOORD0;
	float4 vDepth		: TEXCOORD1;
};

DepthOutVertexShadow BranchFrondVSShadow( float4 inPosition			: POSITION,
										  float4 inNormal			: NORMAL,
										  float2 inWind				: TEXCOORD0,
										  float2 inDetail			: TEXCOORD1,
										  float  instanceIdx		: TEXCOORD4)
{
	DepthOutVertexShadow OUT = (DepthOutVertexShadow)0;

	float2 inTexCoord = float2( inPosition.w, inNormal.w);
	inNormal.w = 0;

	float4 outPosition;
	outPosition.w = 1.0f;
	outPosition.xyz = inPosition.xyz;
	
	// 인스턴싱 사용 시: 마지막 두 인자를 사용
	{
		// 회전 적용
		outPosition.x = inPosition.x * m_avInstanceData[instanceIdx].z/*cos*/ + inPosition.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		outPosition.y = inPosition.y * m_avInstanceData[instanceIdx].z/*cos*/ - inPosition.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// g_matWorld를 그대로 사용 하지 않고 변형 : 스케일링, 위치 적용
		g_matWorld[0] = float4( m_avInstanceData[instanceIdx].x, 0, 0, 0);
		g_matWorld[1] = float4( 0, m_avInstanceData[instanceIdx].x, 0, 0);
		g_matWorld[2] = float4( 0, 0, m_avInstanceData[instanceIdx].x, 0);
		g_matWorld[3] = float4( m_avInstancePosition[instanceIdx].xyz, 1);
		// 윈드 오프셋
		g_fWindMatrixOffset = m_avInstanceData[instanceIdx].w;
	}


	float4x4 matWorldView = mul( g_matWorld, g_matView);
	float4x4 matWorldViewProjection = mul( g_matWorld, g_matViewProjection);
		
	outPosition.xyz = WindEffect(outPosition.xyz, inWind);

	OUT.vPosition = mul(outPosition, matWorldViewProjection );

	OUT.vBaseTexCoords	= inTexCoord;

	OUT.vDepth = mul(outPosition, matWorldView);
	OUT.vDepth.x = g_fAlphaRef;	// vDepth.x에 알파 테스트 레퍼런스
	
	return OUT;
}


DepthOutVertexShadow LeafCardVSShadow(
							float4	vPosition			: POSITION,  // xyz = position, w = corner index
							float4	vTexCoord0			: TEXCOORD0, // xy = diffuse texcoords, zw = compressed wind parameters
							float4	vTexCoord1			: TEXCOORD1, // .x = width, .y = height, .z = pivot x, .w = pivot.y
							float4	vTexCoord2			: TEXCOORD2, // .x = angle.x, .y = angle.y, .z = wind angle index, .w = dimming
							float  instanceIdx			: TEXCOORD4)				
{
    // this will be fed to the leaf pixel shader
    DepthOutVertexShadow sOutput = (DepthOutVertexShadow)0;
    
    // define attribute aliases for readability
    float fAzimuth = g_vLightAngles.x;       // light azimuth for billboarding
    float fPitch = g_vLightAngles.y;         // light pitch for billboarding
    float2 vSize = vTexCoord1.xy;            // leaf card width & height
    int nCorner = vPosition.w;               // which card corner this vertex represents [0,3]
    float fRotAngleX = vTexCoord2.x;         // angle offset for leaf rocking (helps make it distinct)
    float fRotAngleY = vTexCoord2.y;         // angle offset for leaf rustling (helps make it distinct)
    float fWindAngleIndex = vTexCoord2.z;    // which wind matrix this leaf card will follow
    float2 vPivotPoint = vTexCoord1.zw;      // point about which card will rock and rustle
    float fDimming = vTexCoord2.w;           // interior leaves are darker (range = [0.0,1.0])
    float2 vWindParams = vTexCoord0.zw;      // compressed wind parameters
    float fAlphaRef = g_fAlphaRef;

	// 인스턴싱 사용 시: 마지막 두 인자를 사용
	{
		// 회전 적용
		float4 inPosition = vPosition;
		vPosition.x = inPosition.x * m_avInstanceData[instanceIdx].z/*cos*/ + inPosition.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vPosition.y = inPosition.y * m_avInstanceData[instanceIdx].z/*cos*/ - inPosition.x * m_avInstanceData[instanceIdx].y/*sin*/;
 		// g_matWorld를 그대로 사용 하지 않고 변형 : 스케일링, 위치 적용
 		g_matWorld[0] = float4( m_avInstanceData[instanceIdx].x, 0, 0, 0);
 		g_matWorld[1] = float4( 0, m_avInstanceData[instanceIdx].x, 0, 0);
 		g_matWorld[2] = float4( 0, 0, m_avInstanceData[instanceIdx].x, 0);
 		g_matWorld[3] = float4( m_avInstancePosition[instanceIdx].xyz, 1);
 		// 윈드 오프셋
 		g_fWindMatrixOffset = m_avInstanceData[instanceIdx].w;
 		// LOD 처리를 위해 알파 레퍼런스 값을 받아 옴.
 		fAlphaRef = m_avInstancePosition[instanceIdx].w;
	}


	float4x4 matWorldView = mul( g_matWorld, g_matView);
	float4x4 matWorldViewProjection = mul( g_matWorld, g_matViewProjection);

    vPosition.xyz = WindEffect(vPosition.xyz, vWindParams);

    // compute rock and rustle values (all trees share the g_avLeafAngles table, but each can be scaled uniquely)
    float2 vLeafRockAndRustle = g_vLeafAngleScalars.xy * g_avLeafAngles[fWindAngleIndex].xy;;
        
    // access g_mLeafUnitSquare matrix with corner index and apply scales
    float3 vPivotedPoint = g_mLeafUnitSquare[nCorner].xyz;

    // adjust by pivot point so rotation occurs around the correct point
    vPivotedPoint.yz += vPivotPoint;
    float3 vCorner = vPivotedPoint * vSize.xyx;

    // rock & rustling on the card corner
    float3x3 matRotation = RotationMatrix_zAxis(fAzimuth + fRotAngleX + vLeafRockAndRustle.y);
    matRotation = mul(matRotation, RotationMatrix_yAxis(fPitch + fRotAngleY + vLeafRockAndRustle.x));

    vCorner = mul(matRotation, vCorner);
    
    // place and scale the leaf card
    vPosition.xyz += vCorner;
    vPosition.w = 1.0f;

	//Self-Shadow 문제로 인해 Light 반대방향으로 이동시켜준다.
	vPosition.xyz -= g_vLightDir *vSize.y *0.5f;
	
	       
    // project position to the screen
	sOutput.vPosition = mul(vPosition, matWorldViewProjection);

    // pass through other texcoords exactly as they were received
    sOutput.vBaseTexCoords.xy = vTexCoord0.xy;

	sOutput.vDepth = mul(vPosition, matWorldView);
	// 뎁스의 x값에 레퍼런스 저장
	sOutput.vDepth.x = fAlphaRef;

    return sOutput;
}

//  LeafMeshVS
DepthOutVertexShadow LeafMeshVSShadow(
							float4	vPosition			: POSITION,   // xyz = position, w = compressed wind param 1
							float4	vTexCoord0			: TEXCOORD0,  // xy = diffuse texcoords, z = wind angle index, w = dimming
							float3	vOrientX			: TEXCOORD1,  // xyz = vector xyz
							float3	vOrientZ			: TEXCOORD2,  // xyz = vector xyz
							float4	vOffset				: TEXCOORD3,  // xyz = mesh placement position, w = compressed wind param 2
							float  instanceIdx			: TEXCOORD4)
{
    // this will be fed to the leaf pixel shader
    DepthOutVertexShadow sOutput = (DepthOutVertexShadow)0;
    
    // define attribute aliases for readability
    float fWindAngleIndex = vTexCoord0.z;       // which wind matrix this leaf card will follow
    float fDimming = vTexCoord0.w;              // interior leaves are darker (range = [0.0,1.0])
    float2 vWindParams = float2(vPosition.w, vOffset.w);
    
    // compute rock and rustle values (all trees share the g_avLeafAngles table), but g_vLeafAngleScalars
    // scales the angles to match wind settings specified in SpeedTreeCAD
    float2 vLeafRockAndRustle = g_vLeafAngleScalars.xy * g_avLeafAngles[fWindAngleIndex].xy;
    
    // vPosition stores the leaf mesh geometry, not yet put into place at position vOffset.
    // leaf meshes rock and rustle, which requires rotations on two axes (rustling is not
    // useful on leaf mesh geometry)
    float3x3 matRockRustle = RotationMatrix_xAxis(vLeafRockAndRustle.x); // rock
    vPosition.xyz = mul(matRockRustle, vPosition.xyz);
    
    // build mesh orientation matrix - cannot be done beforehand on CPU due to wind effect / rotation order issues.
    // it is used to orient each mesh into place at vOffset

//    vOrientX = -vOrientX;
    float3 vOrientY = cross(vOrientX, vOrientZ);

    float3x3 matOrientMesh =
    {
        vOrientX, vOrientY, vOrientZ
    };
    
    // apply orientation matrix to the mesh positon & normal
    vPosition.xyz = mul(matOrientMesh, vPosition.xyz);

	// 인스턴싱 사용 시: 마지막 두 인자를 사용
	{
		// 위치 : 회전 적용
		float4 inPosition = vPosition;
		vPosition.x = inPosition.x * m_avInstanceData[instanceIdx].z/*cos*/ + inPosition.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vPosition.y = inPosition.y * m_avInstanceData[instanceIdx].z/*cos*/ - inPosition.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// 오프셋 : 회전 적용
		float4 inOffset = vOffset;
		vOffset.x = inOffset.x * m_avInstanceData[instanceIdx].z/*cos*/ + inOffset.y * m_avInstanceData[instanceIdx].y/*sin*/;
 		vOffset.y = inOffset.y * m_avInstanceData[instanceIdx].z/*cos*/ - inOffset.x * m_avInstanceData[instanceIdx].y/*sin*/;
		// g_matWorld를 그대로 사용 하지 않고 변형 : 스케일링, 위치 적용
		g_matWorld[0] = float4( m_avInstanceData[instanceIdx].x, 0, 0, 0);
		g_matWorld[1] = float4( 0, m_avInstanceData[instanceIdx].x, 0, 0);
		g_matWorld[2] = float4( 0, 0, m_avInstanceData[instanceIdx].x, 0);
		g_matWorld[3] = float4( m_avInstancePosition[instanceIdx].xyz, 1);
		// 윈드 오프셋
		g_fWindMatrixOffset = m_avInstanceData[instanceIdx].w;
	}


	float4x4 matWorldView = mul( g_matWorld, g_matView);
	float4x4 matWorldViewProjection = mul( g_matWorld, g_matViewProjection);

	// and has the wind effect motion applied to it
    vOffset.xyz = WindEffect(vOffset.xyz, vWindParams);
    
    // put oriented mesh into place at rotated and wind-affected vOffset
    vPosition.xyz += vOffset.xyz;

	float4 outPosition = float4(vPosition.xyz, 1);
	outPosition.w = 1.0f;

    // project position to the screen
	sOutput.vPosition = mul(outPosition, matWorldViewProjection);

    // pass through other texcoords exactly as they were received
    sOutput.vBaseTexCoords.xy = vTexCoord0.xy;

	sOutput.vDepth = mul(outPosition, matWorldView);
	sOutput.vDepth.x = g_fAlphaRef;	// vDepth.x에 알파 테스트 레퍼런스

    return sOutput;
}


///////////////////////////////////////////////////////////////////////  
//  Billboard1VS
//
//  In order to ensure smooth LOD transitions, two billboards are rendered
//  per tree instance.  Each billboard represents a partially faded rendering
//  of the two closest billboard images for the current camera azimuth and
//  current tree instance rotation.
//
//  Separate shaders are necessary because since different equations are used
//  to pick the billboard index and fade values for the two bb's.

DepthOutVertexShadow Billboard1VSShadow(	float4 vPosition      : POSITION,     // xyz = position, w = corner index
										    float4 vGeom          : TEXCOORD0,    // x = width, y = height, z = tree azimuth, w = lod fade
											float4 vMiscParams    : TEXCOORD1,    // x = scale, y = texcoord offset, z = num images, w = 360 transition %
											float3 vLightAdjusts  : TEXCOORD2)    // x = bright side adjustment, y = dark side adjustment, z = ambient scale
{
    //global float4 g_v360TexCoords[NUM_360_IMAGES];
    
    // this will be fed to the frond pixel shader
    DepthOutVertexShadow sOutput = (DepthOutVertexShadow)0;
   
    // define attribute aliases for readability
    float fAzimuth = g_vCameraAngles.x;         // current camera azimuth
    float fPitch = g_vCameraAngles.y;           // current camera pitch
    int nCorner = vPosition.w;                  // which card corner this vertex represents [0,3]
    int nNumImages = vMiscParams.z;             // # of 360-degree images
    float c_fSliceDiameter = c_fTwoPi / float(nNumImages); // diameter = 360 / g_nNum360Images
    float c_fLodFade = vGeom.w;                 // computed on CPU - the amount the billboard as a whole is faded from 3D geometry
    float c_fTreeScale = vMiscParams.x;         // uniform scale of tree instance
    float c_fTransitionPercentage = vMiscParams.w;  // controls how thick or thin the 360-degree image transition is 
    int nTexCoordTableOffset = vMiscParams.y;   // offset into g_v360TexCoords where this instance's texcoords begin
    
    // there are two azimuth values to consider:
    //    1) fAzimuth: the azimuth of the camera position
    //    2) fAdjustedAzimuth: the azimuth of the camera plus the orientation of the tree the billboard 
    //                         represents (used to determine which bb image to use and its alpha value)
    
    // modify the adjusted azimuth to appear in range [0,2*pi]
    float fAdjustedAzimuth = g_fSpecialAzimuth - vGeom.z;
    if (fAdjustedAzimuth < 0.0f)
        fAdjustedAzimuth += c_fTwoPi;
    if (fAdjustedAzimuth > c_fTwoPi)
        fAdjustedAzimuth -= c_fTwoPi;
        
    // pick the billboard image index and access the extract texcoords from the table
    int nIndex0 = int(fAdjustedAzimuth / c_fSliceDiameter);
    if (nIndex0 > nNumImages - 1)
        nIndex0 = 0;

    // compute the alpha fade value
	float fAlpha0 = (fAdjustedAzimuth - (nIndex0 * c_fSliceDiameter)) / c_fSliceDiameter;

    float fFadePoint = lerp(c_fClearAlpha, c_fOpaqueAlpha, c_fLodFade);
    
    // 4.1 (helps reduce a too-faded look)
    fAlpha0 = max(fAlpha0, c_fTransitionPercentage);
    //  warning X3571: pow(f, e) will not work for negative f, use abs(f) or conditionally handle negative values if you expect them. so must saturate
    fAlpha0 = lerp(fFadePoint, c_fClearAlpha, pow( saturate((fAlpha0 - c_fTransitionPercentage) / (1.0f - c_fTransitionPercentage)), 1.7f));
    
    // each billboard may be faded at a distinct value, but it isn't efficient to change
    // the alpha test value per billboard.  instead we adjust the alpha value of the 
    // billboards's outgoing color to achieve the same effect against a static alpha test 
    // value (c_gOpaqueAlpha).
    fAlpha0 = 1.0f - (fAlpha0 - c_fOpaqueAlpha) / c_fAlphaSpread;

    // multiply by the correct corner
    float3 vecCorner = g_mBBUnitSquare[nCorner].xyz * vGeom.xxy * c_fTreeScale;

    // apply rotation to scaled corner
    vecCorner.xy = float2(dot(g_vCameraAzimuthTrig.yxw, vecCorner.xyz), dot(g_vCameraAzimuthTrig.zyw, vecCorner.xyz));

    vPosition.xyz += vecCorner;
    vPosition.w = 1.0f;

    // project to the screen
	sOutput.vPosition = mul(vPosition, g_matViewProjection);

	float4x4 matWorldView = mul( g_matWorld, g_matView);
	sOutput.vDepth = mul(vPosition, g_matView);
	// 알파 테스트 팩터는 x에 저장
	sOutput.vDepth.x = fAlpha0;

    // determine texcoords based on corner position - while not a straighforward method for determining the texcoords
    // for a specific corner, this one provided a good compromise of speed and space
    float4 vTexCoords = g_v360TexCoords[nIndex0 + nTexCoordTableOffset];
    sOutput.vBaseTexCoords.x = vTexCoords.x - vTexCoords.z * g_afTexCoordScales[nCorner].x;
    sOutput.vBaseTexCoords.y = vTexCoords.y - vTexCoords.w * g_afTexCoordScales[nCorner].y;
    
    return sOutput;
}



DepthOutVertexShadow Billboard2VSShadow(	float4 vPosition      : POSITION,     // xyz = position, w = corner index
											float4 vGeom          : TEXCOORD0,    // x = width, y = height, z = tree azimuth, w = lod fade
											float4 vMiscParams    : TEXCOORD1,    // x = scale, y = texcoord offset, z = num images, w = 360 transition %
											float3 vLightAdjusts  : TEXCOORD2)    // x = bright side adjustment, y = dark side adjustment, z = ambient scale
{
    // this will be fed to the frond pixel shader
    DepthOutVertexShadow sOutput = (DepthOutVertexShadow)0;
    
    // define attribute aliases for readability
    float fAzimuth = g_vCameraAngles.x;         // current camera azimuth
    float fPitch = g_vCameraAngles.y;           // current camera pitch
    int nCorner = vPosition.w;                  // which card corner this vertex represents [0,3]
    int nNumImages = vMiscParams.z;             // # of 360-degree images
    float c_fSliceDiameter = c_fTwoPi / float(nNumImages); // diameter = 360 / g_nNum360Images
    float c_fLodFade = vGeom.w;                 // computed on CPU - the amount the billboard as a whole is faded from 3D geometry
    float c_fTreeScale = vMiscParams.x;         // uniform scale of tree instance
    float c_fTransitionPercentage = vMiscParams.w;  // controls how thick or thin the 360-degree image transition is 
    int nTexCoordTableOffset = vMiscParams.y;   // offset into g_v360TexCoords where this instance's texcoords begin
    
    // there are two azimuth values to consider:
    //    1) fAzimuth: the azimuth of the camera position
    //    2) fAdjustedAzimuth: the azimuth of the camera plus the orientation of the tree the billboard 
    //                         represents (used to determine which bb image to use and its alpha value)

    // modify the adjusted azimuth to appear in range [0,2*pi]
    float fAdjustedAzimuth = g_fSpecialAzimuth - vGeom.z;
    if (fAdjustedAzimuth < 0.0f)
        fAdjustedAzimuth += c_fTwoPi;
    if (fAdjustedAzimuth > c_fTwoPi)
        fAdjustedAzimuth -= c_fTwoPi;
            
    // pick the index and access the texcoords
//  int nIndex1 = int(fAdjustedAzimuth / c_fSliceDiameter);
	int nIndex1 = int(fAdjustedAzimuth / c_fSliceDiameter + 1);
    if (nIndex1 > nNumImages - 1)
        nIndex1 = 0;
    
    // compute the alpha fade value
	float fAlpha1 = 1.0f - Modulate_Float(fAdjustedAzimuth, c_fSliceDiameter) / c_fSliceDiameter;

    float fFadePoint = lerp(c_fClearAlpha, c_fOpaqueAlpha, c_fLodFade);
    
    // 4.1 (helps reduce a too-faded look)
    fAlpha1 = max(fAlpha1, c_fTransitionPercentage);
    //  warning X3571: pow(f, e) will not work for negative f, use abs(f) or conditionally handle negative values if you expect them. so must saturate
    fAlpha1 = lerp(fFadePoint, c_fClearAlpha, pow( saturate((fAlpha1 - c_fTransitionPercentage) / (1.0f - c_fTransitionPercentage)), 1.7f));
    
    // each billboard may be faded at a distinct value, but it isn't efficient to change
    // the alpha test value per billboard.  instead we adjust the alpha value of the 
    // billboards's outgoing color to achieve the same effect against a static alpha test 
    // value (c_gOpaqueAlpha).
    fAlpha1 = 1.0f - (fAlpha1 - c_fOpaqueAlpha) / c_fAlphaSpread;

    // multiply by the correct corner
    float3 vecCorner = g_mBBUnitSquare[nCorner].xyz * vGeom.xxy * c_fTreeScale;

    // apply rotation to scaled corner
    vecCorner.xy = float2(dot(g_vCameraAzimuthTrig.yxw, vecCorner.xyz), dot(g_vCameraAzimuthTrig.zyw, vecCorner.xyz));
    vPosition.xyz += vecCorner;
    vPosition.w = 1.0f;
    
	// project to the screen
	sOutput.vPosition = mul(vPosition, g_matViewProjection);
	
	float4x4 matWorldView = mul( g_matWorld, g_matView);
	sOutput.vDepth = mul(vPosition, g_matView);
	// 알파 테스트 팩터는 x에 저장
	sOutput.vDepth.x = fAlpha1;
	
	// determine texcoords based on corner position - while not a straighforward method for determining the texcoords
    // for a specific corner, this one provided a good compromise of speed and space
    float4 vTexCoords = g_v360TexCoords[nIndex1 + nTexCoordTableOffset];
    sOutput.vBaseTexCoords.x = vTexCoords.x - vTexCoords.z * g_afTexCoordScales[nCorner].x;
    sOutput.vBaseTexCoords.y = vTexCoords.y - vTexCoords.w * g_afTexCoordScales[nCorner].y; 
    
    return sOutput;
}	



float4 GetShadowMapValueWithAlphaTest(float fValue, float2 vTexcoord, float fAlphaFactor, float fAlphaRef, sampler sam)
{
	float4 vResult =float4(fValue, fValue, fValue, tex2D( sam, vTexcoord).a);
	float fAlpha = vResult.a * fAlphaFactor;
	clip( fAlpha - fAlphaRef);
	
    return vResult;
}

float4 DepthPSShadow(DepthOutVertexShadow In) : COLOR
{
	return float4(In.vDepth.z, In.vDepth.z, In.vDepth.z, 1);
}

float4 DepthPSShadowWithAlphaTest(DepthOutVertexShadow In) : COLOR
{
	// 리프카드는 vDepth.x에 알파 레퍼런스 저장
	return GetShadowMapValueWithAlphaTest(In.vDepth.z, In.vBaseTexCoords.xy, 1, In.vDepth.x, samComposite);
}

float4 DepthPSShadowWithBillboard(DepthOutVertexShadow In) : COLOR
{
	// 빌보드는 vDepth.x에 알파 팩터를 저장
	return GetShadowMapValueWithAlphaTest(In.vDepth.z, In.vBaseTexCoords.xy, In.vDepth.x, g_fAlphaRef, samBillboardDiffuseMap);
}

float4 DepthPSProjectionShadow(DepthOutVertexShadow In) : COLOR
{
	return float4(g_ShadowValue, g_ShadowValue, g_ShadowValue, 1);	
}

float4 DepthPSProjectionShadowWithAlphaTest(DepthOutVertexShadow In) : COLOR
{
	return GetShadowMapValueWithAlphaTest(g_ShadowValue, In.vBaseTexCoords.xy, 1, In.vDepth.x, samComposite);
}

float4 DepthPSProjectionShadowWithBillboard(DepthOutVertexShadow In) : COLOR
{
	return GetShadowMapValueWithAlphaTest(In.vDepth.z, In.vBaseTexCoords.xy, In.vDepth.x, g_fAlphaRef, samBillboardDiffuseMap);
}

///////////////////////////////////////////////////////////////////////////////////
/// Shadow

technique BranchShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 BranchFrondVSShadow();
        PixelShader = compile ps_3_0 DepthPSShadow();
    }
}

technique FrondShadow
{
	pass P0
	{
		VertexShader = compile vs_3_0 BranchFrondVSShadow();
		PixelShader = compile ps_3_0 DepthPSShadowWithAlphaTest();
	}
}

technique LeafCardShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 LeafCardVSShadow();
        PixelShader = compile ps_3_0 DepthPSShadowWithAlphaTest();
    }
}

technique LeafMeshShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 LeafMeshVSShadow();
        PixelShader = compile ps_3_0 DepthPSShadowWithAlphaTest();
    }
}

technique BillboardShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 Billboard1VSShadow();
        PixelShader = compile ps_3_0 DepthPSShadowWithBillboard();
    }
	pass P1
	{
        VertexShader = compile vs_3_0 Billboard2VSShadow();
        PixelShader = compile ps_3_0 DepthPSShadowWithBillboard();
	}
}


///////////////////////////////////////////////////////////////////////////////////
/// Projection Shadow

technique BranchProjectionShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 BranchFrondVSShadow();
        PixelShader = compile ps_3_0 DepthPSProjectionShadow();
    }
}

technique FrondProjectionShadow
{
	pass P0
	{
		VertexShader = compile vs_3_0 BranchFrondVSShadow();
		PixelShader = compile ps_3_0 DepthPSProjectionShadowWithAlphaTest();
	}
}

technique LeafCardProjectionShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 LeafCardVSShadow();
        PixelShader = compile ps_3_0 DepthPSProjectionShadowWithAlphaTest();
    }
}

technique LeafMeshProjectionShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 LeafMeshVSShadow();
        PixelShader = compile ps_3_0 DepthPSProjectionShadowWithAlphaTest();
    }
}

technique BillboardProjectionShadow
{
    pass P0
    {          
        VertexShader = compile vs_3_0 Billboard1VSShadow();
        PixelShader = compile ps_3_0 DepthPSProjectionShadowWithBillboard();
    }
	pass P1
	{
        VertexShader = compile vs_3_0 Billboard2VSShadow();
        PixelShader = compile ps_3_0 DepthPSProjectionShadowWithBillboard();
	}
}