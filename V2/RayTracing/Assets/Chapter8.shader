
// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

Shader "Unlit/RayTracingSphere"
{
    Properties
    {
        _CameraOrigin ("Camera Origin", Vector) = (0, 0, -10, 1) // camera pos
        _ViewportSize ("Viewport Size", Vector) = (10, 5, 5, 0) // quad pos from camera scale 10(x), 5(y). and 5(z) away from camera.
        _SamplesPerPixel ("Samples Per Pixel", Range(1, 100)) = 10
    }

    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #define INFINITY 1e20
            static const float PI = 3.14159265359;

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
            int _SamplesPerPixel;

            // Convert UVs to viewport space
            float3 get_pixel_position(float2 uv, float2 sample_offset) {
                return _CameraOrigin - float3(
                    _ViewportSize.x * (uv.x - 0.5 + sample_offset.x),
                    _ViewportSize.y * (uv.y - 0.5 + sample_offset.y),
                    _ViewportSize.z
                );
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // Random number generator
            float random_float(float2 uv) {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Returns a random offset for jittering inside a pixel
            float2 random_sample_offset(int index) {
                float base2 = 0.5, base3 = 1.0 / 3.0;
                float r2 = 0.0, r3 = 0.0, f2 = base2, f3 = base3;

                for (int i = index; i > 0; i /= 2) {
                    r2 += f2 * (i % 2);
                    f2 *= 0.5;
                }
    
                for (int i = index; i > 0; i /= 3) {
                    r3 += f3 * (i % 3);
                    f3 *= 1.0 / 3.0;
                }

                return float2(r2, r3) - 0.5; // Offset to center
            }

            struct Interval {
                float min;
                float max;
            };

            // Define constants for empty and universe intervals
            static const Interval INTERVAL_EMPTY = { +INFINITY, -INFINITY };
            static const Interval INTERVAL_UNIVERSE = { -INFINITY, +INFINITY };

            // Function to get the size of the interval
            float interval_size(Interval interval) {
                return interval.max - interval.min;
            }

            // Function to check if a value is within the interval
            bool interval_contains(Interval interval, float x) {
                return interval.min <= x && x <= interval.max;
            }

            // Function to check if a value is strictly inside the interval
            bool interval_surrounds(Interval interval, float x) {
                return interval.min < x && x < interval.max;
            }

            float interval_clamp(Interval interval, float x) {
                return clamp(x, interval.min, interval.max);
            }

            float3 sample_square(float2 uv) {
                return float3(random_float(uv) - 0.5, random_float(uv.yx) - 0.5, 0);
            }

            // Function to set the front face normal based on the ray direction
            void set_face_normal(float3 ray_direction, float3 outward_normal, out float3 normal, out bool front_face)
            {
                front_face = dot(ray_direction, outward_normal) < 0.0;
                normal = front_face ? outward_normal : -outward_normal;
            }

            // Function to check ray-sphere intersection
            bool hit_sphere(float3 center, float radius, float3 origin, float3 direction, Interval ray_t, out float t)
            {
                float3 oc = origin - center;
                float a = dot(direction, direction);
                float h = dot(direction, oc);
                float c = dot(oc, oc) - radius * radius; 
                float discriminant = h * h - a * c;

                if (discriminant < 0) 
                {
                    t = -1.0;
                    return false;
                }

                float sqrt_discriminant = sqrt(discriminant);

                // First root (closer intersection)
                float root = (-h - sqrt_discriminant) / a;
                if (!interval_surrounds(ray_t, root)) 
                {
                    // Try second root (farther intersection)
                    root = (-h + sqrt_discriminant) / a;
                    if (!interval_surrounds(ray_t, root)) {
                        return false;
                    }
                }

                t = root;
                return true;
            }

            // Function to calculate ray color
            float4 ray_color(float3 origin, float3 direction)
            {
                float t;
                Interval ray_t = { 0.0, INFINITY };

                // Define two spheres: a main sphere and a ground sphere
                float3 sphere1_center = float3(0.0, 0.0, -1.0);  // Main sphere 
                float sphere1_radius = 0.45;  // Main sphere radius
                float3 sphere2_center = float3(0.0, 100.5, -1.0);  // Ground sphere
                float sphere2_radius = 100.0;  // Ground sphere radius

                // Check if the ray intersects the first sphere (main sphere)
                if (hit_sphere(sphere1_center, sphere1_radius, origin, direction, ray_t, t))
                {
                    // Calculate the hit point
                    float3 hit_point = origin + t * direction;

                    // Calculate the normal at the intersection point
                    float3 outward_normal = normalize(hit_point - sphere1_center);

                    // Set front-face normal
                    float3 normal;
                    bool front_face;
                    set_face_normal(direction, outward_normal, normal, front_face);

                    // Return a color based on the normal (shaded according to the sphere surface)
                    return 0.5 * float4(normal.x + 1.0, 1 - normal.y + 1.0, normal.z + 1.0, 1.0);
                }

                // Check if the ray intersects the second sphere (ground sphere)
                if (hit_sphere(sphere2_center, sphere2_radius, origin, direction, ray_t, t))
                {
                    // Calculate the hit point
                    float3 hit_point = origin + t * direction;

                    // Calculate the normal at the intersection point
                    float3 outward_normal = normalize(hit_point - sphere2_center);

                    // Set front-face normal
                    float3 normal;
                    bool front_face;
                    set_face_normal(direction, outward_normal, normal, front_face);

                    // Return a color based on the normal (shaded according to the ground surface)
                    return 0.5 * float4(normal.x + 1.0, 1 - normal.y + 1.0, normal.z + 1.0, 1.0);
                }

                // If no intersection, return a gradient sky color
                float t_sky = 0.5 * (direction.y + 1.0);  // Sky gradient
                float3 sky_color = lerp(float3(1.0, 1.0, 1.0), float3(0.5, 0.7, 1.0), t_sky);
                return float4(sky_color, 1.0);
            }

            // Fragment shader function
            fixed4 frag(v2f i) : SV_Target
            {
                float3 color = float3(0, 0, 0);

                // Average multiple samples per pixel
                for (int sample = 0; sample < _SamplesPerPixel; sample++)
                {
                    float2 sample_offset = random_sample_offset(sample) * 0.01; // Jitter within pixel
                    float3 pixel_pos = get_pixel_position(i.uv, sample_offset);
                    float3 ray_dir = normalize(pixel_pos - _CameraOrigin);
                    color += ray_color(_CameraOrigin, ray_dir);
                }

                // Average colors
                color /= _SamplesPerPixel;

                return float4(color, 1.0);
            }
            ENDCG
        }
    }
}