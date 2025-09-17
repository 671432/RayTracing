
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

    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            typedef vector<float, 3> vec3;  // vector3 type
            typedef vector<fixed, 3> col3;  // fixed color type (normalized between 0-1)

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

            float3 _CameraOrigin;
            float3 _ViewportSize;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // Fragment shader function
            fixed4 frag(v2f i) : SV_Target
            {
                // Calculate ray direction based on UV coordinates
                float3 pixelPos = _CameraOrigin - float3(_ViewportSize.x * (i.uv.x - 0.5), _ViewportSize.y * (i.uv.y - 0.5), _ViewportSize.z);
                float3 rayDirection = normalize(pixelPos - _CameraOrigin);

                // Calculate the blending factor (vertical direction of ray)
                float a = 0.5 * (rayDirection.y + 1.0);

                // colors
                fixed3 colorA = fixed3(0.5, 0.7, 1.0);  // light blue
                fixed3 colorB = fixed3(1.0, 1.0, 1.0);  // white 

                fixed3 color = lerp(colorA, colorB, a);  // blend based on ray's direction

                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
}