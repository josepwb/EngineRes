interface()
{
	$name = layer_2ndblend_overlay
	$define = layer_2ndblend
}

float4 DiffuseLayer2ndBlend(float4 color0, float4 color1)
{
	float4 vBlendedColor = 2.0f * color0 * color1;
	vBlendedColor += (2*(color0+color1)-1 -2*vBlendedColor) * (color0>0.5);

	return vBlendedColor;
}