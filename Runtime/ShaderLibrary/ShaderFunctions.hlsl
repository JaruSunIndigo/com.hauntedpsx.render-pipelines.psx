#ifndef PSX_SHADER_FUNCTIONS
#define PSX_SHADER_FUNCTIONS

#include "Packages/com.hauntedpsx.render-pipelines.psx/Runtime/ShaderLibrary/ShaderVariables.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

float TonemapperGenericScalar(float x)
{
    return saturate(
        pow(x, _TonemapperContrast) 
        / (pow(x, _TonemapperContrast * _TonemapperShoulder) * _TonemapperGraypointCoefficients.x + _TonemapperGraypointCoefficients.y)
    );
}

// Improved crosstalk - maintaining saturation.
// http://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
// https://www.shadertoy.com/view/XljBRK
float3 TonemapperGeneric(float3 rgb)
{
    float peak = max(max(rgb.r, max(rgb.g, rgb.b)), 1.0f / (256.0f * 65536.0f));
    float3 ratio = rgb / peak;
    peak = TonemapperGenericScalar(peak);

    ratio = pow(max(0.0f, ratio), (_TonemapperSaturation + _TonemapperContrast) / _TonemapperCrossTalkSaturation);
    ratio = lerp(ratio, float3(1.0f, 1.0f, 1.0f), pow(peak, _TonemapperCrossTalk));
    ratio = pow(max(0.0f, ratio), _TonemapperCrossTalkSaturation);

    return ratio * peak;
}

float HashShadertoy(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898f, 78.233f))) * 43758.5453123f);
}

// https://en.wikipedia.org/wiki/YUV
// YUV color space used in PAL RF and composite signals.
// Note: These transforms expect linear RGB, not perceptual sRGB.
// Convert [0, 1] range RGB values to Y[0, 1], U[-0.436, 0.436], V[-0.615, 0.615] space.
float3 YUVFromRGB(float3 rgb)
{
    float3 yuv;

    yuv.x = rgb.x * 0.299 + 0.587 * rgb.y + 0.114 * rgb.z;
    yuv.y = (rgb.z - yuv.x) * (0.436 / (1.0 - 0.114));
    yuv.z = (rgb.x - yuv.x) * (0.615 / (1.0 - 0.299));

    return yuv;
}

// Convert [0, 1] range RGB values to YUV[0, 1] range normalized values (for convenient discretization and storage).
float3 YUVNormalizedFromRGB(float3 rgb)
{
    float3 yuv = YUVFromRGB(rgb);

    const float2 UV_MAX = float2(0.436, 0.615);
    const float2 UV_MIN = -UV_MAX;
    const float2 UV_RANGE = UV_MAX - UV_MIN;
    const float2 UV_SCALE = 1.0 / UV_RANGE;
    const float2 UV_BIAS = -UV_MIN / UV_RANGE;
    
    yuv.yz = yuv.yz * UV_SCALE + UV_BIAS;

    return yuv;
}

float3 RGBFromYUV(float3 yuv)
{
    return float3(
        yuv.x * 1.0 + yuv.y * 0.0 + yuv.z * 1.1383,
        yuv.x * 1.0 + yuv.y * -0.39465 + yuv.z * -0.5806,
        yuv.x * 1.0 + yuv.y * 2.03211 + yuv.z * 0.0
    );
}

float3 RGBFromYUVNormalized(float3 yuv)
{
    const float2 UV_MAX = float2(0.436, 0.615);
    const float2 UV_MIN = -UV_MAX;
    const float2 UV_RANGE = UV_MAX - UV_MIN;
    const float2 UV_SCALE = UV_RANGE;
    const float2 UV_BIAS = UV_MIN;
    
    yuv.yz  = yuv.yz * UV_SCALE + UV_BIAS;

    float3 rgb = RGBFromYUV(yuv);

    return rgb;
}

// https://en.wikipedia.org/wiki/YIQ
// YIQ color space used in NTSC RF and composite signals.

// FCC NTSC YIQ Standard
// Converts from perceptual / gamma corrected sRGB color space to gamma corrected YIQ space.
float3 FCCYIQFromSRGB(float3 srgb)
{
    float3 yiq = float3(
        srgb.r * 0.30 + srgb.g * 0.59 + srgb.b * 0.11,
        srgb.r * 0.599 + srgb.g * -0.2773 + srgb.b * -0.3217,
        srgb.r * 0.213 + srgb.g * -0.5251 + srgb.b * 0.3121
    );

    return yiq;
}

float3 SRGBFromFCCYIQ(float3 yiq)
{
    float3 srgb = float3(
        yiq.x + yiq.y * 0.9469 + yiq.z * 0.6236,
        yiq.x + yiq.y * -0.2748 + yiq.z * -0.6357,
        yiq.x + yiq.y * -1.1 + yiq.z * 1.7
    );

    return srgb;
}

// Low Complexity, High Fidelity: The Rendering of INSIDE
// https://youtu.be/RdN06E6Xn9E?t=1337
// Remaps a [0, 1] value to [-0.5, 1.5] range with a triangular distribution.
float NoiseDitherRemapTriangularDistribution(float v)
{
    float orig = v * 2.0 - 1.0;
    float c0 = 1.0 - sqrt(saturate(1.0 - abs(orig)));
    return 0.5 + ((orig >= 0.0) ? c0 : -c0);
}

float3 NoiseDitherRemapTriangularDistribution(float3 v)
{
    float3 orig = v * 2.0 - 1.0;
    float3 c0 = 1.0 - sqrt(saturate(1.0 - abs(orig)));
    return 0.5 + float3(
        (orig.x >= 0.0) ? c0.x : -c0.x,
        (orig.y >= 0.0) ? c0.y : -c0.y,
        (orig.z >= 0.0) ? c0.z : -c0.z
    );
}

#endif