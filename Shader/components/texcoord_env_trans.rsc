interface()
{
	$name		= texcoord_env_trans
	$dependency	= texcoord
}

void PSMAIN(inout PSOUTPUT output)
{
	float2 vEnvironmentCoord = 0;
	IMPORT( E_vEnvironmentCoord, vEnvironmentCoord = E_vEnvironmentCoord );
	vEnvironmentCoord = ApplyUVTransform(vEnvironmentCoord, g_UVTransform[2]);

	EXPORT( float2, E_vEnvironmentCoord, vEnvironmentCoord );
}