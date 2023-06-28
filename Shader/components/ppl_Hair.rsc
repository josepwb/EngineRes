interface()
{
	$name = HairSpec
	$define = HairSpec
}

shared float2		g_HairLightingShift						= float2( 0.57684f, 0.60411f );
shared float2		g_HairLightingSpecularIntensity	= float2( 73.0f, 27.0f );
shared float4		g_HairSpecularColor1					= float4( 0.7f, 0.6f, 0.4f, 1.0f );
shared float4		g_HairSpecularColor2					= float4( 0.7f, 0.4f, 0.1f, 1.0f );
shared float2		g_HairSpecularConcentration		= float2( 0.5f, 0.5f );
shared float		g_HairSpecularAmplitude				= 0.f;

float3 ShiftTangent( float3 T, float3 N, float shift )
{
        float3 shiftedT = T + shift * N;
        return normalize(shiftedT);
}


float HairSingleSpecularTerm( float3 T, float3 H, float exponent )
{
        float dotTH = dot( T,  H );
        float sinTH = sqrt( 1.0f - dotTH * dotTH );
        float dirAtten = smoothstep( -1.0f, 0.0f, dotTH );
        return dirAtten * pow( sinTH, exponent );
}

struct VSOUTPUT
{
	float3 vWorldPos	: TEXCOORD%;
	float4 vTangent	: TEXCOORD%;
};

void VSMAIN(inout VSOUTPUT output)
{
	float4 vWorldPosition = 0;
	IMPORT(E_vWorldPosition, vWorldPosition = E_vWorldPosition);
	output.vWorldPos = vWorldPosition.xyz;

	float4 vLocalTangent = 0;
	IMPORT( E_vLocalTangent, vLocalTangent = E_vLocalTangent);
	float3 vTangent = normalize( mul(  vLocalTangent.xyz, (float3x3)g_matWorldView ));
	output.vTangent.xyz = vTangent;
}

void PSMAIN(VSOUTPUT input, inout PSOUTPUT output)
{
	float3 vSpecularMask = 0;
	IMPORT( E_vSpecularMaskColor, vSpecularMask = E_vSpecularMaskColor);			// 마스크,
	
	float3 vSpecularShift = 0;
	IMPORT( E_vSpecularShiftColor, vSpecularShift.rgb = E_vSpecularShiftColor);	 	// 쉬프트

	float3 vNormal = 0;
	IMPORT( E_pgNormal, vNormal = E_pgNormal);
	
	float3 toEye = mul( input.vWorldPos, (float3x3)g_matView ).xyz;
	toEye = normalize( toEye );
	
	if( 0 < g_HairSpecularAmplitude )
	{
		vNormal.xyz = pow(vNormal.xyz, g_HairSpecularAmplitude);
		input.vTangent.xyz = pow(input.vTangent.xyz, g_HairSpecularAmplitude);
	}
		
	float shiftTex = vSpecularShift.r - 0.5f;
	float3 t1 = ShiftTangent( input.vTangent.xyz, vNormal, g_HairLightingShift.x + shiftTex);
	float3 t2 = ShiftTangent( input.vTangent.xyz, vNormal, g_HairLightingShift.y + shiftTex);
	
	float3 lightVec = -g_vLightVec;
	lightVec = normalize(lightVec);
	
	float3 H = normalize( lightVec + toEye );

	float3 specular		= g_HairSpecularColor1 * HairSingleSpecularTerm( t1, H, g_HairLightingSpecularIntensity.x );
	float3 specular2		= g_HairSpecularColor2 * HairSingleSpecularTerm( t2, H, g_HairLightingSpecularIntensity.y );

	float specMask	= vSpecularMask.r;
	specular2			*= specMask;
	
    float specularAttenuation = saturate( 1.75f * dot( vNormal, lightVec) + 0.25f );
    specular = (specular * g_HairSpecularConcentration.x + specular2 * g_HairSpecularConcentration.y) * specularAttenuation;
    
    float3 vSpecular = specular;
    EXPORT( float3, E_vAddColor, vSpecular);
}
