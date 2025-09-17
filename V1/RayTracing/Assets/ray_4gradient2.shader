
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
        float y = 1.0 - i.uv.y; // -1 to invert the Y-axis (Top to Bottom)

        // Defining colors
        fixed3 colorA = fixed3(0.9, 0, 0.8);
        fixed3 colorB = fixed3(1, 1, 1);
        fixed3 colorC = fixed3(0, 1, 1);
        fixed3 colorD = fixed3(0, 0, 0);

        // Calculate distance to the diagonals of the screen
        float dist1 = abs(x - y); // Distance from top-left to bottom-right diagonal
        float dist2 = abs((1.0 - x) - y); // Distance from bottom-left to top-right diagonal

        // Blend the colors based on the distances
        fixed3 col1 = lerp(colorA, colorB, dist1);
        fixed3 col2 = lerp(colorD, colorC, dist1);
        fixed3 col = lerp(col1, col2, (dist1+dist2));

        return fixed4(col, 1);
	}
////////////////////////////////////////////////////////////////////////////////////


ENDCG

}}}
