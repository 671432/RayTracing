
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

            // Function to check ray-sphere intersection
            bool hit_sphere(float3 center, float radius, float3 origin, float3 direction)
            {
                float3 oc = origin - center;
                float a = dot(direction, direction);
                float b = 2.0 * dot(oc, direction);
                float c = dot(oc, oc) - radius * radius;
                float discriminant = (b * b) - (4.0 * a * c);
                return discriminant >= 0.0;
            }

            // Function to calculate ray color
            float4 ray_color(float3 origin, float3 direction)
            {
                // Check for intersection with a red sphere centered at (0, 0, -1) with radius 0.45
                if (hit_sphere(float3(0, 0, -1), 0.45, origin, direction))
                {
                    return float4(1.0, 0.0, 0.0, 1.0); // Red color for sphere
                }

                // Gradient sky color
                float t = 0.5 * (direction.y + 1.0);
                float3 sky_color = lerp(float3(1.0, 1.0, 1.0), float3(0.5, 0.7, 1.0), t);
                return float4(sky_color, 1.0);
            }

            // Fragment shader function
            fixed4 frag(v2f i) : SV_Target
            {
                // Calculate the ray's direction
                float3 pixel_pos = _CameraOrigin - float3(_ViewportSize.x * (i.uv.x - 0.5), _ViewportSize.y * (i.uv.y - 0.5), _ViewportSize.z);
                float3 ray_dir = normalize(pixel_pos - _CameraOrigin);

                // Return the color based on ray intersection with the sphere
                return ray_color(_CameraOrigin, ray_dir);
            }
            ENDCG
        }
    }
}