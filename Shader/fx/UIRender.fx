sampler UITexture	: register(s0);
sampler UITextureMask	: register(s1);

float2 g_f2TexelSize;
float2 g_f2InvScreenSize;


float3 g_f2Position[5];
float3 g_f2TexCoord[5];
float3 g_f2TexCoord1[5];
float4 g_f4ColorsArray[5];

float		g_fWidth;
float		g_fHeight;


struct VS_INPUT_STD
{
	float3 		vPos : POSITION;
};

struct VS_OUTPUT_STD
{
	float4 Position				: POSITION;
	float4 Color					: COLOR;
	float2 TC0					: TEXCOORD0;
};


struct VS_OUTPUT_MASK
{
	float4 Position				: POSITION;
	float4 Color					: COLOR;
	float2 TC0					: TEXCOORD0;
	float2 TC1					: TEXCOORD1;
};


struct VS_OUTPUT_PIXEL2D
{
	float4 Position				: POSITION;
	float4 Color					: COLOR;
};

////////////////////////////////////////////////////////////////////////////////////////////////////
// ÀÏ¹Ý Ä¿½ºÅÒ UI

VS_OUTPUT_STD RenderGPUQuadVS( VS_INPUT_STD IN  )
{
	VS_OUTPUT_STD OUT = (VS_OUTPUT_STD)0;
	
	float2 f2PositionArray;
	float2 f2TexCoordArray;
	float4 f4ColorArray;
	
	int iIndex = (int)IN.vPos.x;

	f2PositionArray		= g_f2Position[ iIndex ].xy;
	f2TexCoordArray	= g_f2TexCoord[ iIndex ].xy;
	f4ColorArray			= g_f4ColorsArray[ iIndex ];
	
	float posX = (f2PositionArray.x / g_fWidth) * 2.f - 1.f;
	float posY = (f2PositionArray.y / g_fHeight) * 2.f - 1.f;
	
	
	
	OUT.Position = float4(posX, -posY, 0.f, 1.0f);
	OUT.TC0		= f2TexCoordArray;
	OUT.Color 	= f4ColorArray;
	
    return OUT;
}


float4 RenderSimpleTexFontPS( VS_OUTPUT_STD IN ) : COLOR
{ 
	return tex2D( UITexture, IN.TC0 )* IN.Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// ¸¶½ºÅ©
VS_OUTPUT_MASK RenderMskVS( VS_INPUT_STD IN  )
{
	VS_OUTPUT_MASK OUT = (VS_OUTPUT_MASK)0;
	
	float2 f2PositionArray;
	float2 f2TexCoordArray;
	float2 f2TexCoordArray1;
	float4 f4ColorArray;
	
	int iIndex = (int)IN.vPos.x;

	f2PositionArray		= g_f2Position[ iIndex ].xy;
	f2TexCoordArray	= g_f2TexCoord[ iIndex ].xy;
	f2TexCoordArray1	= g_f2TexCoord1[ iIndex ].xy;
	f4ColorArray			= g_f4ColorsArray[ iIndex ];
	
	float posX = (f2PositionArray.x / g_fWidth) * 2.f - 1.f;
	float posY = (f2PositionArray.y / g_fHeight) * 2.f - 1.f;
	
	
	
	OUT.Position = float4(posX, -posY, 0.f, 1.0f);
	OUT.TC0		= f2TexCoordArray;
	OUT.TC1		= f2TexCoordArray1;
	OUT.Color 	= f4ColorArray;
	
    return OUT;
}



float4 RenderMaskUI( VS_OUTPUT_MASK IN ) : COLOR
{ 
	return tex2D( UITextureMask, IN.TC1 ).a *  tex2D( UITexture, IN.TC0 ) * IN.Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// ÇÈ¼¿2D

VS_OUTPUT_PIXEL2D RenderPixel2DVS( VS_INPUT_STD IN  )
{
	VS_OUTPUT_PIXEL2D OUT = (VS_OUTPUT_PIXEL2D)0;
	
	float2 f2PositionArray;
	float2 f2TexCoordArray;
	float4 f4ColorArray;
	
	int iIndex = (int)IN.vPos.x;

	f2PositionArray		= g_f2Position[ iIndex ].xy;
	f4ColorArray			= g_f4ColorsArray[ iIndex ];
	
	float posX = (f2PositionArray.x / g_fWidth) * 2.f - 1.f;
	float posY = (f2PositionArray.y / g_fHeight) * 2.f - 1.f;
	

	OUT.Position = float4(posX, -posY, 0.f, 1.0f);
	OUT.Color = f4ColorArray;

	
    return OUT;
}


float4 RenderPixel2DUI( VS_OUTPUT_PIXEL2D IN ) : COLOR
{ 
	return IN.Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////////

technique RenderGPUFont
{
    pass P0
    {          
        VertexShader = compile vs_3_0 RenderGPUQuadVS();
        PixelShader  = compile ps_3_0 RenderSimpleTexFontPS();
    }
	
	
	// ¸¶½ºÅ©
	pass P1
    {          
        VertexShader = compile vs_3_0 RenderMskVS();
        PixelShader  = compile ps_3_0 RenderMaskUI();
    }
	
	// ÇÈ¼¿2D
	pass P1
    {          
        VertexShader = compile vs_3_0 RenderPixel2DVS();
        PixelShader  = compile ps_3_0 RenderPixel2DUI();
    }
}

