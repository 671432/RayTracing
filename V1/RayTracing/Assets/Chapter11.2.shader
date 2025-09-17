
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
        _camPos("Camera Position", Vector) = (0, 0, 0, 1)
        _lookAt("Look At", Vector) = (0, 0, 0, 0)
        _ViewportSize ("Viewport Size", Vector) = (16, 9, 9, 0)
        
        // Sliders for user inputs
        _samplesPerPixel ("Antialiasing (SPP)", Range(1, 10)) = 3
        _raysPerPixel("Rays Per Pixel (RPP)", Range(1, 50)) = 1
        _bounces("Bounces", Range(0, 10)) = 1
        _gamma("Gamma", Range(0.0, 1.0)) = 0.5
        _reflection ("Reflection", Range(0, 1)) = 1

        // Sphere properties
        _sphere1XAxis("Spheres X-Axis", Range(-2, 2)) = 0
        _sphere1YAxis("Spheres Y-Axis", Range(-1.5, 1.5)) = 0
        _sphere1ZAxis("Spheres Z-Axis", Range(-1.5, 1.5)) = 0

        _sphere2XAxis("Ground X-Axis", Range(-100, 100)) = 0
        _sphere2YAxis("Ground Y-Axis", Range(-100, 100)) = 0
        _sphere2ZAxis("Ground Z-Axis", Range(-1000, 1000)) = 0

        //_sphereFuzz1("Left Sphere Fuzz", Range(0, 1)) = 0.3
        _sphereFuzz2("Right Sphere Fuzz", Range(0, 1)) = 1.0
        _sphereRefraction1("Left Sphere Refraction", Range(0, 5)) = 1.5
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
            int _samplesPerPixel;
            float _raysPerPixel;
            int _bounces;
            float _gamma;
            float _reflection;
            float _sphere1XAxis;
            float _sphere1YAxis;
            float _sphere1ZAxis;
            float _sphere2XAxis;
            float _sphere2YAxis;
            float _sphere2ZAxis;
            //float _sphereFuzz1;
            float _sphereFuzz2;
            float _sphereRefraction1;
            

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
            
            // Generate a random point on a hemisphere
            inline float3 random_on_hemisphere(float3 normal) {
                float3 on_unit_sphere = random_unit_vector();
                if (dot(on_unit_sphere, normal) > 0.0) // In the same hemisphere as the normal
                    return on_unit_sphere;
                else
                    return -on_unit_sphere;
            }

            float3 scatter_lambertian(float3 normal) {
                // Generate a random unit vector in a hemisphere
                float3 scatter_direction = normal + random_unit_vector();

                // Prevent zero-length scatter direction
                if (length(scatter_direction) < 1e-8)
                    scatter_direction = normal;

                return normalize(scatter_direction);
            }

            float3 reflect(float3 v, float3 n) {
                return (_reflection * (v - 2 * dot(n, v) * n));
            }

            float3 refract(float3 uv, float3 n, float etai_over_etat) {
                float cos_theta = min(dot(-uv, n), 1.0);
                float3 r_out_perp = etai_over_etat * (uv + cos_theta * n);
                float3 r_out_parallel = -sqrt(abs(1.0 - dot(r_out_perp, r_out_perp))) * n;
                return r_out_perp + r_out_parallel;
            }

            float3 scatter_dielectric(float3 incident, float3 normal, float refraction_index, bool front_face) {
                float ri = front_face ? (1.0 / refraction_index) : refraction_index;

                float3 unit_direction = normalize(incident);
                float cos_theta = min(dot(-unit_direction, normal), 1.0);
                float sin_theta = sqrt(1.0 - cos_theta * cos_theta);

                float3 direction = refract(unit_direction, normal, ri);

                return direction;
            }

            float3 scatter_metal(float3 incident, float3 normal, float fuzz) {
                // Reflect the incident ray around the normal
                float3 reflected = reflect(normalize(incident), normal);
    
                reflected += fuzz * normalize(random_unit_vector() * normal);

                return normalize(reflected);
            }

            struct Material {
                int type;        // 0 = Lambertian, 1 = Metal, 2 = Dielectric
                float3 albedo;   // Base color
                float fuzz;      // Fuzziness (only for type metal)
                float refraction_index; // refraction
            };

            struct Sphere {
                float3 center;
                float radius;
                Material material;
            };

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
            bool hit_sphere(Sphere sphere, float3 origin, float3 direction, Interval ray_t, out float t, out Material hitMaterial)
            {
                float3 oc = origin - sphere.center;
                float a = dot(direction, direction);
                float h = dot(direction, oc);
                float c = dot(oc, oc) - sphere.radius * sphere.radius; 
                float discriminant = h * h - a * c;

                if (discriminant < 0) 
                {
                    t = -1.0;
                    return false;
                }

                float sqrt_discriminant = sqrt(discriminant);
                float root = (-h - sqrt_discriminant) / a;
                if (!interval_clamp(ray_t, root) || root < 0.001) 
                {
                    root = (-h + sqrt_discriminant) / a;
                    if (!interval_clamp(ray_t, root) || root < 0.001) {
                        return false;
                    }
                }
                
                t = root;
                hitMaterial = sphere.material;
                return true;
            }

            // Function to calculate ray color
            float4 ray_color(float3 origin, float3 direction)
            {
                float t;
                Material hitMaterial;
                Interval ray_t = { 0.0, INFINITY };

                //main
                Sphere spheres[4];
                spheres[0].center = float3(_sphere1XAxis, _sphere1YAxis, _sphere1ZAxis - 1.2);
                spheres[0].radius = 0.45;
                spheres[0].material.type = 0;
                spheres[0].material.albedo = float3(0.1, 0.2, 0.5);
                //left
                spheres[1].center = float3(_sphere1XAxis+1.0, _sphere1YAxis, _sphere1ZAxis - 1.0);
                spheres[1].radius = 0.45;
                spheres[1].material.type = 2;
                spheres[1].material.albedo = float3(0.8, 0.8, 0.8);
                spheres[1].material.refraction_index = _sphereRefraction1;
                //right
                spheres[2].center = float3(_sphere1XAxis-1.0, _sphere1YAxis, _sphere1ZAxis - 1.0);
                spheres[2].radius = 0.45;
                spheres[2].material.type = 1;
                spheres[2].material.albedo = float3(0.8, 0.6, 0.2);
                spheres[2].material.fuzz = _sphereFuzz2;
                //ground
                spheres[3].center = float3(_sphere2XAxis, 100.5 + _sphere2YAxis, _sphere2ZAxis - 1.0);
                spheres[3].radius = 100.0;
                spheres[3].material.type = 0;
                spheres[3].material.albedo = float3(0.8, 0.8, 0.0);


                float3 final_color = float3(1, 1, 1);
                float3 attenuation = float3(1, 1, 1);

                for (int bounce = 0; bounce < _bounces; bounce++) {
                    bool hit_anything = false;
                    for (int i = 0; i < 4; i++) {
                        if (hit_sphere(spheres[i], origin, direction, ray_t, t, hitMaterial)) {
                            hit_anything = true;
                            float3 hit_point = origin + t * direction;
                            float3 normal = normalize(hit_point - spheres[i].center);

                            // Update direction based on material
                            if (hitMaterial.type == 0) {  // Lambertian
                                direction = scatter_lambertian(normal);
                            } 
                            else if (hitMaterial.type == 1) {  // Metal
                                direction = scatter_metal(direction, normal, hitMaterial.fuzz);
                            }
                            else if (hitMaterial.type == 2) {  // Refraction
                                // Determine if the ray is entering or exiting
                                bool front_face = dot(direction, normal) < 0.0;
                                direction = scatter_dielectric(direction, normal, hitMaterial.refraction_index, front_face);
                            }

                            // Accumulate attenuation (energy loss with each bounce)
                            attenuation *= hitMaterial.albedo;
                            origin = hit_point;  // Move the ray's origin to the hit point
                            break;
                        }
                    }

                    if (!hit_anything) {
                        float t_sky = 0.5 * (direction.y + 1.0);
                        final_color *= lerp(float3(1.0, 1.0, 1.0), float3(0.5, 0.7, 1.0), t_sky);
                        break;
                    }
                }
                return _gamma * float4(final_color * attenuation, 1.0);
            }

            // Fragment shader function
            fixed4 frag(v2f i) : SV_Target
            {
                float3 color = float3(0, 0, 0);

                // Loop over antialiasing samples
                for (int sample = 0; sample < _samplesPerPixel; sample++)
                {
                    float2 sample_offset = random_sample_offset(sample) * 0.002; // Small jitter
                    float3 pixel_pos = get_pixel_position(i.uv, sample_offset);

                    // Loop over multiple rays per pixel
                    for (int ray = 0; ray < _raysPerPixel; ray++)
                    {
                        // Add randomness to ray direction for reflections
                        float3 ray_dir = normalize(pixel_pos - _camPos + random_unit_vector() * 0.05);
                        color += ray_color(_camPos, ray_dir);
                    }
                }

                // Average over total samples and rays
                color /= (_samplesPerPixel * _raysPerPixel);

                return float4(color, 1.0);
            }
            ENDCG
        }
    }
}           