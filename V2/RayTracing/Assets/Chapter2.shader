
// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

Shader "Unlit/GradientShader"
{
    Properties
    {
        _CameraOrigin ("Camera Origin", Vector) = (0, 0, -10, 1) // camera pos
        _ViewportSize ("Viewport Size", Vector) = (10, 5, 5, 0) // quad pos from camera scale 10(x), 5(y). and 5(z) away from camera.
    }

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

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

            fixed4 frag(v2f i) : SV_Target
            {
                // Normalize the uv coordinates to [0, 1] range
                float r = i.uv.x; // Red based on  x-coordinate
                float g = i.uv.y; // Green based on y-coordinate
                float b = 0.0;    // Blue always 0

                // return the colors
                return fixed4(r, g, b, 1.0);
            }

            ENDCG
        }
    }
}
