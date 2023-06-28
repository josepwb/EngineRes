interface()
{
	$name = layer_1stblend_overlay
	$define = layer_1stblend
}

float4 DiffuseLayer1stBlend(float4 color0, float4 color1)
{
	float4 vBlendedColor = 2.0f * color0 * color1;
	vBlendedColor += (2*(color0+color1)-1 -2*vBlendedColor) * (color0>0.5f);

	return vBlendedColor;
}