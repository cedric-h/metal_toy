/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands.
#include "AAPLShaderTypes.h"

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant AAPLVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]]
) {
    RasterizerData out;

    out.position.xy = vertices[vertexID].position.xy;
    out.position.z = 0.0;
    out.position.w = 1.0;

    // Pass the input color directly to the rasterizer.
    out.color.xy = vertices[vertexID].position.xy;

    return out;
}

//fragment float4 fragmentShader(
//             RasterizerData in [[stage_in]],
//             constant vector_uint2 *viewportSizePointer [[buffer(AAPLVertexInputIndexViewportSize)]],
//             constant float *iTime [[buffer(AAPLVertexInputIndexViewportSize+1)]]
//) {
//    float2 uv = (in.color.xy * vector_float2(*viewportSizePointer) + 0.4) * 0.005 + float(*iTime);
//    
//    float2 grid = abs(fract(uv - 0.5) - 0.5);
//    float h = min(grid.x, grid.y);
//    
//    float afwidth = length(float2(dfdx(h), dfdy(h))) * 0.70710678118654757;
//    float col = smoothstep(0.035-afwidth, 0.035+afwidth, h);
//    
//    // return float4(float3(col), 1.0);
//    return float4(float3(col), 1.0);
//}

float mod(float x, float y) { return x - y * floor(x / y); }
float hexDist(float2 p, float s) {
    p.x *= 0.57735*2.0;
    p.y += mod(floor(p.x), 2.0)*0.5;
    p.x = mod(p.x, 1.0);
    p.y = mod(p.y, 1.0);
    p = abs((p - 0.5));
    return abs(max(p.x*1.5 + p.y, p.y*2.0) - 1.0) / s;
}

float remap(
    float value,
    float low1, float high1,
    float low2, float high2
) {
    return low2 + (value - low1) * (high2 - low2) / (high1 - low1);
}

float aastep(float cutoff, float value) {
    float afwidth = length(float2(dfdx(value), dfdy(value))) * 0.70710678118654757;
    return smoothstep(cutoff+afwidth, cutoff-afwidth, value);
}

float easeOutCubic(float x) {
    float inv_x = 1.0 - x;
    return 1 - inv_x * inv_x * inv_x;
}

fragment float4 fragmentShader(
             RasterizerData in [[stage_in]],
             constant vector_uint2 *pViewportSize [[buffer(AAPLVertexInputIndexViewportSize)]],
             constant float2 *pMouse [[buffer(AAPLVertexInputIndexViewportSize+1)]],
             constant float *pTime [[buffer(AAPLVertexInputIndexViewportSize+2)]]
) {
    // float2 uv = (in.color.xy * vector_float2(*viewportSizePointer) + 0.4) * 0.001 + float(*iTime);
    float2 iViewportSize = vector_float2(*pViewportSize);
    float2 iMouse = vector_float2(*pMouse);
    float iTime = float(*pTime);
    
    float dist;
    {
        /* extra /2 to account for hiDPI, LMAO */

        float2 aspect = float2(1, iViewportSize.y/iViewportSize.x);
        float _dist = length(in.color.xy*aspect - (iMouse/iViewportSize*4 - 1)*aspect);

        float t = easeOutCubic(clamp(iTime/2, 0.0, 1.0));
        // dist = aastep(0.15*sin(t * M_PI_F * 2), _dist);

        float donut_center = 0.35 * t;
        float donut_center_dist = abs(_dist - donut_center);
        // dist = smoothstep(0.2, 0.5, donut_center_dist);

        {
            float solid = 0.02 * sin(t * M_PI_F);
            float edge = 0.045 * clamp((1.0 - t) / 0.3, 0.0, 1.0);
            dist = smoothstep(solid - edge, solid + edge, donut_center_dist);
        }
        dist = clamp(dist, 0.0, 1.0);
    }
    
    // return float4(float3(dist), 1);
        
    float2 uv = (in.color.xy * iViewportSize + 0.4) * 0.005;
    
    float hex = aastep(-0.01, hexDist(uv, 0.2) - 0.5);
    
    float2 _sqr = abs(fract(uv - 0.5) - 0.5);
    float sqr = aastep(0, fmin(_sqr.x, _sqr.y) - 0.05);

    float col = 0;
    col += sqr*(0 + dist);
    col += hex*(1 - dist);
    return float4(float3(col), 1.0);
}

