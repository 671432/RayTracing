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
        // sliders for camera controll
        _CameraPos("Camera Position", Vector) = (0, 0, 0, 1)
        _VerticalFOV("Field of View", Range(0.01, 179)) = 90
        _LookAt("Look At", Vector) = (0, 0, 0)
        _VUP("View Up", Vector) = (0, 1, 0)
        _ViewportSize ("Viewport Size", Vector) = (16, 9, 9, 0)

        // Sliders for user inputs
        _SamplesPerPixel("Antialiasing (SPP)", Range(1, 20)) = 3
        _raysPerPixel("Rays Per Pixel (RPP)", Range(1, 50)) = 1
        _MaxBounces("Bounces", Range(0, 10)) = 1
        _Gamma("Gamma", Range(0.0, 10)) = 1
        _reflection ("Reflection", Range(0, 1)) = 1
        _LightDir ("Light Direction", Vector) = (1, 1, 1)

        // Sphere properties
        _sphere1XAxis("Spheres X-Axis", Range(-2, 2)) = 0
        _sphere1YAxis("Spheres Y-Axis", Range(-1.5, 1.5)) = 0
        _sphere1ZAxis("Spheres Z-Axis", Range(-1.5, 1.5)) = 0

        _sphere2XAxis("Ground X-Axis", Range(-100, 100)) = 0
        _sphere2YAxis("Ground Y-Axis", Range(-100, 100)) = 0
        _sphere2ZAxis("Ground Z-Axis", Range(-1000, 1000)) = 0

        _RightFuzz("Right Sphere Fuzz", Range(0, 1)) = 1.0
        _LeftRefraction("Left Sphere Refraction", Range(0, 1.0)) = 0.5
    }

    SubShader { Pass {
    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag

    float4 _CameraPos, _LookAt;

    float3 _VUP, _ViewportSize, _LightDir;

    float _VerticalFOV, _Gamma, _reflection;
    float _sphere1XAxis, _sphere1YAxis, _sphere1ZAxis, 
    _sphere2XAxis, _sphere2YAxis, _sphere2ZAxis;
    float _LeftRefraction, _RightFuzz;

    int _SamplesPerPixel, _MaxBounces, _raysPerPixel;

    struct appdata {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct v2f {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
    };

    struct Ray {
        float3 origin;
        float3 direction;
    };

    struct Sphere {
        float3 center;
        float radius;
        int type;
    };

    v2f vert(appdata v) {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        return o;
    }

    float3 ray_at(Ray r, float t) {
        return r.origin + t * r.direction;
    }

    // Function to check ray-sphere intersection
    float hit_sphere(Sphere s, Ray r) {
        float3 oc = r.origin - s.center;
        float a = dot(r.direction, r.direction);
        float b = 2.0 * dot(oc, r.direction);
        float c = dot(oc, oc) - s.radius * s.radius;
        float discriminant = b * b - 4.0 * a * c;
        return (discriminant < 0.0) ? -1.0 : (-b - sqrt(discriminant)) / (2.0 * a);
    }

    // Random number generator
    float rand(float2 seed) {
        return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
    }

    float3 random_in_unit_sphere(float2 seed, int offset) {
        return normalize(float3(
            rand(seed + float2(offset, 1)),
            rand(seed + float2(offset, 2)),
            rand(seed + float2(offset, 3))
        ) * 2.0 - 1.0);
    }

    float3 reflect(float3 v, float3 n) {
        return (_reflection * (v - 2 * dot(n, v) * n));
    }

    float3 refract(float3 uv, float3 n, float eta) {
        float cos_theta = min(dot(-uv, n), 1.0);
        float3 r_out_perp = eta * (uv + cos_theta * n);
        float3 r_out_parallel = -sqrt(abs(1.0 - dot(r_out_perp, r_out_perp))) * n;
        return r_out_perp + r_out_parallel;
    }

    float3 scatter_dielectric(float3 dir, float3 normal, float ri, bool front_face) {
        float refraction_ratio = front_face ? (1.0 / ri) : ri;
        float cos_theta = min(dot(-dir, normal), 1.0);
        float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
        bool cannot_refract = refraction_ratio * sin_theta > 1.0;
        return normalize(cannot_refract ? reflect(dir, normal) : refract(dir, normal, refraction_ratio));
    }

    float3 scatter_metal(float3 dir, float3 normal, float fuzz) {
        // Reflect the incident ray around the normal
        float3 reflected = reflect(normalize(dir), normal);
        return normalize(reflected + fuzz * random_in_unit_sphere(normal.xy, rand(dir + 1)));
    }

    // Convert UVs to viewport
    Ray get_camera_ray(float2 uv) {
        float aspect_ratio = _ViewportSize.x / _ViewportSize.y;

        // Convert FOV from degrees to radians
        float theta = radians(_VerticalFOV);
        float half_height = tan(theta * 0.5);
        float half_width = aspect_ratio * half_height;
        float half_depth = _ViewportSize.z/2;

        // Compute camera vectors
        float3 w = normalize(_CameraPos - _LookAt); // Camera direction (pointing backwards)
        float3 u = normalize(cross(_VUP, w)); // Right vector
        float3 v = cross(w, u); // True "up" vector

        Ray r;
        r.origin = _CameraPos.xyz;
        // Compute pixel position based on the new coordinates
        // return half_xyz because directly using _ViewportSize.xyz made issues
        r.direction = normalize(_CameraPos - w
                    + (3.0 * half_width * (uv.x - 0.5)) * u
                    + (3.0 * half_height * (uv.y - 0.5)) * v);
        return r;
    }

    // Function to calculate ray color
    float3 get_ray_color(Ray r, int max_bounces) {
        float3 color = float3(1, 1, 1);

        float3 lightDir = normalize(_LightDir); // ← Directional light

        for (int b = 0; b < max_bounces; ++b) {
            float t_min = 1e20;
            int hitIndex = -1;
            float3 hitPoint, normal;

            Sphere spheres[5];
            //left
            spheres[0].center = float3(_sphere1XAxis-1, _sphere1YAxis, _sphere1ZAxis-1);
            spheres[0].radius = 0.5;
            spheres[0].type = 2;
            //bubble
            spheres[1].center = float3(_sphere1XAxis-1, _sphere1YAxis, _sphere1ZAxis-1);
            spheres[1].radius = -0.4;
            spheres[1].type = 2;
            //center
            spheres[2].center = float3(_sphere1XAxis, _sphere1YAxis, _sphere1ZAxis-1.2);
            spheres[2].radius = 0.5;
            spheres[2].type = 0;
            //right
            spheres[3].center = float3(_sphere1XAxis+1, _sphere1YAxis, _sphere1ZAxis-1);
            spheres[3].radius = 0.5;
            spheres[3].type = 1;
            //ground
            spheres[4].center = float3(_sphere2XAxis, -100.5 + _sphere2YAxis, _sphere2ZAxis - 1.0);
            spheres[4].radius = 100.0;
            spheres[4].type = 3;

            for (int i = 0; i < 5; ++i) {
                float t = hit_sphere(spheres[i], r);
                if (t > 0.001 && t < t_min) {
                    t_min = t;
                    hitIndex = i;
                }
            }

            if (hitIndex == -1) {
                float t = 0.5 * (r.direction.y + 1.0);
                return color * lerp(float3(1,1,1), float3(0.5,0.7,1.0), t);
            }

            hitPoint = ray_at(r, t_min);
            normal = normalize(hitPoint - spheres[hitIndex].center);
            if (spheres[hitIndex].radius < 0.0) normal = -normal;
            bool front_face = dot(r.direction, normal) < 0.0;

            // Shadow ray
            Ray shadowRay;
            shadowRay.origin = hitPoint + normal * 0.001; // offset to prevent acne
            shadowRay.direction = lightDir;

            bool inShadow = false;
            for (int i = 0; i < 5; ++i) {
                float shadowT = hit_sphere(spheres[i], shadowRay);
                if (shadowT > 0.001) {
                    inShadow = true;
                    break;
                }
            }

            float shadowFactor = inShadow ? 0.1 : 1.0;

            // Update direction based on material
            if (spheres[hitIndex].type == 0) { // Lambertian
                r.origin = hitPoint;
                r.direction = normalize(normal + random_in_unit_sphere(hitPoint.xy, b));
                color *= float3(0.1, 0.2, 0.5) * shadowFactor;
            }
            else if (spheres[hitIndex].type == 1) { // Metal
                r.origin = hitPoint;
                r.direction = scatter_metal(r.direction, normal, _RightFuzz);
                color *= float3(0.8, 0.6, 0.2) * shadowFactor;
            }
            else if (spheres[hitIndex].type == 2) { // Refraction
                r.origin = hitPoint;
                r.direction = scatter_dielectric(r.direction, normal, _LeftRefraction, front_face);
                color *= float3(0.9, 0.9, 0.9);
            }
            else if (spheres[hitIndex].type == 3) { // Lambertian
                color *= float3(0.2, 0.8, 0.2) * shadowFactor;
                break;
            }
        }
        return color;
    }

    // Fragment shader function
    fixed4 frag(v2f i) : SV_Target {
        float3 col = float3(0, 0, 0);

        // Loop over antialiasing samples
        for (int sample = 0; sample < _SamplesPerPixel; ++sample) {
            float2 jitter = float2(rand(i.uv + float2(sample, 0)), rand(i.uv + float2(0, sample))); // Small jitter
            float2 uv = i.uv + jitter * 0.002;

            float3 sampleCol = float3(0, 0, 0);

            // Loop over multiple rays per pixel
            for (int r = 0; r < _raysPerPixel; ++r) {
                Ray ray = get_camera_ray(uv);
                sampleCol += get_ray_color(ray, _MaxBounces);
            }
            sampleCol /= _raysPerPixel;

            col += sampleCol;
        }

        // Average over total samples and rays
        col /= _SamplesPerPixel;
        col = pow(col, float3(1.0 / _Gamma, 1.0 / _Gamma, 1.0 / _Gamma));
        return fixed4(col, 1.0);
    }
    ENDCG
    }}
}
