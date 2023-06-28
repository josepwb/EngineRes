interface()
{
	$name = layer_result_export
	$define = diffusemap
}

void PSMAIN( inout PSOUTPUT output)
{
	float4 vCompositeResult;
	IMPORT( E_vDiffuseColor, vCompositeResult = E_vDiffuseColor);
	
	g_vSavedAlpha[ REFLECT_DIFFUSE ] = vCompositeResult.a;
	g_fReflect[ REFLECT_DIFFUSE ] = vCompositeResult.a;
	g_fFakeSSSMask[ REFLECT_DIFFUSE ] = vCompositeResult.a;

	EXPORT(float4, E_vDiffuseColor, vCompositeResult);
	EXPORT(float, E_fDiffuseAlpha, vCompositeResult.a);
}
