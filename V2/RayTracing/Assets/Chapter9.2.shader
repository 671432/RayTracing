
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
        _camPos("Camera Position", Vector) = (0, 0, 0, 1) // camera pos
        _lookAt("Look At", Vector) = (0, 0, 0, 0)
        _ViewportSize ("Viewport Size", Vector) = (16, 9, 9, 0) // quad pos from camera scale 10(x), 5(y). and 5(z) away from camera.
        
        // Sliders for user inputs
        _SamplesPerPixel ("Antialiasing (SPP)", Range(1, 100)) = 10
        _raysPerPixel("Rays Per Pixel (RPP)", Range(1, 1000)) = 1
        _bounces("Bounces", Range(0, 10)) = 0

        _sphere1XAxis("Sphere1 X-Axis", Range(-5, 5)) = 0
        _sphere1YAxis("Sphere1 Y-Axis", Range(-10, 10)) = 0
        _sphere1ZAxis("Sphere1 Z-Axis", Range(-10, 10)) = 0

        _sphere2XAxis("Sphere2 X-Axis", Range(-100, 100)) = 0
        _sphere2YAxis("Sphere2 Y-Axis", Range(-100, 100)) = 0
        _sphere2ZAxis("Sphere2 Z-Axis", Range(-1000, 1000)) = 0

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

            float4 _camPos;
            float4 _lookAt;
            float3 _ViewportSize;
            int _SamplesPerPixel;
            float _raysPerPixel;
            float _bounces;
            float _sphere1XAxis;
            float _sphere1YAxis;
            float _sphere1ZAxis;
            float _sphere2XAxis;
            float _sphere2YAxis;
            float _sphere2ZAxis;

            // Convert UVs to viewport space
            float3 get_pixel_position(float2 uv, float2 sample_offset) {
                return _camPos - float3(
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
                float2 noise = (frac(sin(dot(uv, float2(12.9898, 78.233)*2.0)) * 43758.5453));
                return abs(noise.x + noise.y) * 0.5;
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

            
            // Generate a random unit vector
            float3 random_unit_vector() {
                float2 rand = float2(random_float(float2(0.0, 1.0)), random_float(float2(1.0, 0.0)));
                float z = 1.0 - 2.0 * rand.x;
                float r = sqrt(max(0.0, 1.0 - z * z));
                float phi = 2.0 * PI * rand.y;
                return float3(r * cos(phi), r * sin(phi), z);
            }
            
            /*
            // Generate a random unit vector
            inline float3 random_unit_vector() {
                int maxAttempts = 50000000; // Set a maximum number of attempts
                int attempts = 0;
    
                while (attempts < maxAttempts) {
                    // Generate random point in the cube space (-1 to 1) for each component
                    float3 p = float3(random_float(float2(0.0, 1.0)) * 2.0 - 1.0, 
                                      random_float(float2(0.0, 1.0)) * 2.0 - 1.0, 
                                      random_float(float2(0.0, 1.0)) * 2.0 - 1.0);
        
                    // Calculate the squared length of the vector
                    float lensq = dot(p, p);
        
                    // If the vector is inside the unit sphere, normalize it
                    if ((1e-160) < lensq && lensq <= 1.0) {
                        return (p / sqrt(lensq)); // Normalize to make sure it's a unit vector
                    }

                    attempts++;
                }

                // Fallback: return a default unit vector if max attempts reached
                return float3(0.8, 0.8, 0.8); // Fallback to a fixed unit vector (avoids (0.5, 0.5, 0.5))
            }
            */


            // Generate a random point on a hemisphere
            inline float3 random_on_hemisphere(float3 normal) {
                float3 on_unit_sphere = random_unit_vector();
                if (dot(on_unit_sphere, normal) > 0.0) // In the same hemisphere as the normal
                    return on_unit_sphere;
                else
                    return -on_unit_sphere;
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
                normal = front_face ? outward_normal : outward_normal;
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

                // Define the two spheres: the main sphere and the ground sphere
                float3 sphere1_center = float3(_sphere1XAxis, _sphere1YAxis, _sphere1ZAxis-1.0);
                float sphere1_radius = 0.45;
                float3 sphere2_center = float3(_sphere2XAxis, 100.5+_sphere2YAxis, _sphere2ZAxis-1.0);
                float sphere2_radius = 100.0;

                // Check if the ray intersects either sphere
                bool hit_first_sphere = hit_sphere(sphere1_center, sphere1_radius, origin, direction, ray_t, t);
                bool hit_second_sphere = hit_sphere(sphere2_center, sphere2_radius, origin, direction, ray_t, t);

                if (hit_first_sphere) {
                    // If the ray hits the first sphere (main sphere), apply shading based on the intersection
                    float3 hit_point = origin + t * direction;
                    float3 outward_normal = normalize(hit_point - sphere1_center);

                    // Calculate normal direction
                    float3 normal;
                    bool front_face;
                    set_face_normal(direction, outward_normal, normal, front_face);

                    // Sample a random direction in the hemisphere (diffuse reflection)
                    float3 light_direction = random_on_hemisphere(normal);
                    float diff = max(dot(normal, light_direction), 0.0);
                    float bounce_factor = exp(-_bounces * 0.1);
                    
                    // Return the color for the main sphere with diffuse shading
                    return 0.5 * float4(diff * bounce_factor * float3(0.8, 0.8, 0.8), 0.5);

                }

                if (hit_second_sphere) {
                    // If the ray hits the second sphere (ground sphere), apply shading based on the intersection
                    float3 hit_point = origin + t * direction;
                    float3 outward_normal = normalize(hit_point - sphere2_center);

                    // Calculate normal direction
                    float3 normal;
                    bool front_face;
                    set_face_normal(direction, outward_normal, normal, front_face);

                    // Sample a random direction in the hemisphere (diffuse reflection)
                    float3 light_direction = random_on_hemisphere(normal);
                    float diff = max(dot(normal, light_direction), 0.0);
                    float bounce_factor = exp(-_bounces * 0.1);

                    // Return the color for the ground sphere with diffuse shading
                    return 0.5 * float4(diff * bounce_factor * float3(0.8, 0.8, 0.8), 0.5);
                }

                // If no intersection with any sphere, return a sky color
                float t_sky = 0.5 * (direction.y + 1.0);  // Sky gradient based on vertical direction
                float3 sky_color = lerp(float3(1.0, 1.0, 1.0), float3(0.5, 0.7, 1.0), t_sky);

                return float4(sky_color, 1.0); // Sky color
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
                    float3 ray_dir = normalize(pixel_pos - _camPos);
                    color += ray_color(_camPos, ray_dir);
                }

                // Average colors
                color /= _SamplesPerPixel;

                return float4(color, 1.0);
            }
            ENDCG
        }
    }
}