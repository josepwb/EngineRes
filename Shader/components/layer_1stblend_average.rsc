interface()
{
	$name = layer_1stblend_average
	$define = layer_1stblend
}

float4 DiffuseLayer1stBlend(float4 color0, float4 color1)
{
	return (color0 + color1)*0.5f;
}