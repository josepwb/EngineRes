#define LAYER_BLEND_AVERAGE		1
#define LAYER_BLEND_ADD				2
#define LAYER_BLEND_SUBTRACT		3
#define LAYER_BLEND_DARKEN			4
#define LAYER_BLEND_MULTIPLY		5
#define LAYER_BLEND_OVERLAY		14

float4 GetBlendColor( in float4 vNormalColor1, in float4 vNormalColor0, in int type )
{
		float4 vBlendedColor = 0;

		[branch]
		if( LAYER_BLEND_OVERLAY == type )
		{
			// ��������
			vBlendedColor = 2.0f * vNormalColor1 * vNormalColor0;
			vBlendedColor += ( 2 * ( vNormalColor0 + vNormalColor1 ) - 1 - 2 * vBlendedColor ) * ( vNormalColor0 > 0.5 );
			vBlendedColor = saturate(vBlendedColor);
		}
		else if( LAYER_BLEND_AVERAGE == type )
		{
			// ���������
			vBlendedColor = ( vNormalColor1 + vNormalColor0 ) * 0.5f;
		}
		else if( LAYER_BLEND_MULTIPLY == type)
		{
			// ��Ƽ�ö���
			vBlendedColor = vNormalColor1 * vNormalColor0;
		}
		else if( LAYER_BLEND_SUBTRACT == type )
		{
			// ����
			vBlendedColor = vNormalColor1 - vNormalColor0;			
		}
		else if( LAYER_BLEND_ADD == type )
		{
			// �ֵ�
			vBlendedColor = vNormalColor1 + vNormalColor0;			
		}
		
		return vBlendedColor;
}