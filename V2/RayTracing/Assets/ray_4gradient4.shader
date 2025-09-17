
// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

Shader "Unlit/SingleColor"
{
		SubShader{ Pass	{
			
	CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag

		typedef vector <float, 3> vec3;  // to get more similar code to book
		typedef vector <fixed, 3> col3;
	
	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
	};
	
	v2f vert(appdata v)
	{
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		return o;
	}
	


////////////////////////////////////////////////////////////////////////////////////////////////////////
	fixed4 frag(v2f i) : SV_Target
	{
                // Get UV coordinates
                float x = i.uv.x;       // Left to Right
                float y = i.uv.y;       // Top to Bottom

                // Defining the colors for the four corners
                fixed3 colorA = fixed3(1, 0, 1); // pink
                fixed3 colorB = fixed3(1, 1, 0); // Yellow 
                fixed3 colorC = fixed3(0, 1, 1); // blue 
                fixed3 colorD = fixed3(0, 1, 0); // Green 

                // Calculate blending factors for each diagonal
                float dist1 = saturate(x - y);  // From top-left to bottom-right
                float dist2 = saturate(x + y);  // From bottom-left to top-right

                // Interpolate between colors for each diagonal
                fixed3 col1 = lerp(colorA, colorC, dist1);
                fixed3 col2 = lerp(colorD, colorB, dist2);

                // final blend
                fixed3 col = lerp(col1, col2, (dist1 + dist2) * 0.5);

                return fixed4(col, 1);  // Return the final color
    }
////////////////////////////////////////////////////////////////////////////////////


ENDCG

}}}
