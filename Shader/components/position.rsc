interface()
{
	$name = position
	$define = position
}

struct VSINPUT
{
	float4 vPosition	: POSITION;
};

void VSMAIN(VSINPUT input)
{
	EXPORT(float4, E_vLocalPosition, input.vPosition);
}