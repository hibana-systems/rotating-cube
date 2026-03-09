#include <metal_stdlib>
using namespace metal;

struct GPUSceneLineInstance {
    float3 startPosition;
    float3 endPosition;
    float4 coreStartColor;
    float4 coreEndColor;
    float4 glowStartColor;
    float4 glowEndColor;
    float coreWidth;
    float glowWidth;
};

struct GPULineVertexUniforms {
    float4x4 viewProjectionMatrix;
    float2 viewportSize;
};

struct GPULinePassUniforms {
    uint passKind;
    uint aaEnabled;
    float edgeFeatherWidth;
    float edgeSoftness;
};

struct GPUBrightPassUniforms {
    float bloomThreshold;
    float3 padding;
};

struct GPUBlurUniforms {
    float2 direction;
    float2 sourceTexelSize;
};

struct GPUCompositeUniforms {
    float2 resolution;
    float bloomIntensity;
    float scanlineIntensity;
    float scanlineDensity;
    float phosphorMaskIntensity;
    float vignetteIntensity;
    float barrelDistortion;
    float cornerPinch;
    float time;
};

struct LineVertexOut {
    float4 position [[position]];
    float4 color;
    float signedDistance;
    float halfWidth;
};

struct FullscreenVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex LineVertexOut lineVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant GPUSceneLineInstance *instances [[buffer(0)]],
    constant GPULineVertexUniforms &uniforms [[buffer(1)]],
    constant GPULinePassUniforms &passUniforms [[buffer(2)]]
) {
    GPUSceneLineInstance instance = instances[instanceID];
    bool isGlowPass = passUniforms.passKind == 1;
    float halfWidth = max((isGlowPass ? instance.glowWidth : instance.coreWidth) * 0.5, 0.5);
    float feather = passUniforms.aaEnabled != 0
        ? max(passUniforms.edgeFeatherWidth * max(passUniforms.edgeSoftness, 0.1), 0.75)
        : 0.0;
    float expandedHalfWidth = halfWidth + feather;

    float4 clipStart = uniforms.viewProjectionMatrix * float4(instance.startPosition, 1.0);
    float4 clipEnd = uniforms.viewProjectionMatrix * float4(instance.endPosition, 1.0);
    float2 ndcStart = clipStart.xy / max(clipStart.w, 0.0001);
    float2 ndcEnd = clipEnd.xy / max(clipEnd.w, 0.0001);

    float2 screenDirection = (ndcEnd - ndcStart) * 0.5 * uniforms.viewportSize;
    float lineLength = max(length(screenDirection), 0.0001);
    float2 normal = float2(-screenDirection.y, screenDirection.x) / lineLength;

    float along = (vertexID == 0 || vertexID == 1) ? 0.0 : 1.0;
    float side = (vertexID == 0 || vertexID == 2) ? -1.0 : 1.0;
    float4 baseClip = mix(clipStart, clipEnd, along);
    float2 offsetNDC = normal * side * expandedHalfWidth * 2.0 / uniforms.viewportSize;

    LineVertexOut out;
    out.position = baseClip;
    out.position.xy += offsetNDC * baseClip.w;
    out.color = mix(
        isGlowPass ? instance.glowStartColor : instance.coreStartColor,
        isGlowPass ? instance.glowEndColor : instance.coreEndColor,
        along
    );
    out.signedDistance = side * expandedHalfWidth;
    out.halfWidth = halfWidth;
    return out;
}

fragment float4 lineFragment(
    LineVertexOut in [[stage_in]],
    constant GPULinePassUniforms &passUniforms [[buffer(0)]]
) {
    float feather = passUniforms.aaEnabled != 0
        ? max(passUniforms.edgeFeatherWidth * max(passUniforms.edgeSoftness, 0.1), 0.75)
        : 0.0;
    float edgeDistance = abs(in.signedDistance) - in.halfWidth;
    float coverage = passUniforms.aaEnabled != 0
        ? clamp(1.0 - smoothstep(0.0, feather, edgeDistance), 0.0, 1.0)
        : (edgeDistance <= 0.0 ? 1.0 : 0.0);
    float alpha = in.color.a * coverage;
    return float4(in.color.rgb * alpha, alpha);
}

vertex FullscreenVertexOut fullscreenVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };
    float2 uvs[3] = {
        float2(0.0, 0.0),
        float2(2.0, 0.0),
        float2(0.0, 2.0)
    };

    FullscreenVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    return out;
}

fragment float4 brightPassFragment(
    FullscreenVertexOut in [[stage_in]],
    texture2d<float> sceneTexture [[texture(0)]],
    sampler linearSampler [[sampler(0)]],
    constant GPUBrightPassUniforms &uniforms [[buffer(0)]]
) {
    float3 color = sceneTexture.sample(linearSampler, in.uv).rgb;
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    float bloomMask = smoothstep(uniforms.bloomThreshold, uniforms.bloomThreshold + 0.25, luminance);
    return float4(color * bloomMask, 1.0);
}

fragment float4 gaussianBlurFragment(
    FullscreenVertexOut in [[stage_in]],
    texture2d<float> sourceTexture [[texture(0)]],
    sampler linearSampler [[sampler(0)]],
    constant GPUBlurUniforms &uniforms [[buffer(0)]]
) {
    constexpr float weights[5] = { 0.227027f, 0.1945946f, 0.1216216f, 0.054054f, 0.016216f };

    float3 color = sourceTexture.sample(linearSampler, in.uv).rgb * weights[0];

    for (uint index = 1; index < 5; ++index) {
        float2 offset = uniforms.direction * uniforms.sourceTexelSize * float(index);
        color += sourceTexture.sample(linearSampler, in.uv + offset).rgb * weights[index];
        color += sourceTexture.sample(linearSampler, in.uv - offset).rgb * weights[index];
    }

    return float4(color, 1.0);
}

fragment float4 crtCompositeFragment(
    FullscreenVertexOut in [[stage_in]],
    texture2d<float> sceneTexture [[texture(0)]],
    texture2d<float> bloomTexture [[texture(1)]],
    sampler linearSampler [[sampler(0)]],
    constant GPUCompositeUniforms &uniforms [[buffer(0)]]
) {
    float2 centered = in.uv * 2.0 - 1.0;
    float aspect = max(uniforms.resolution.x / max(uniforms.resolution.y, 1.0), 0.0001);
    float2 aspectCentered = float2(centered.x * aspect, centered.y);
    float radiusSquared = dot(aspectCentered, aspectCentered);
    float radialWarp = 1.0 + uniforms.barrelDistortion * radiusSquared;
    float cornerWeight = smoothstep(0.15, 1.0, radiusSquared);

    aspectCentered *= radialWarp;
    aspectCentered -= float2(
        aspectCentered.x * fabs(aspectCentered.y),
        aspectCentered.y * fabs(aspectCentered.x)
    ) * uniforms.cornerPinch * cornerWeight;

    float2 warped = float2(aspectCentered.x / aspect, aspectCentered.y);
    float2 sampleUV = warped * 0.5 + 0.5;

    if (any(sampleUV < 0.0) || any(sampleUV > 1.0)) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    float3 sceneColor = sceneTexture.sample(linearSampler, sampleUV).rgb;
    float3 bloomColor = bloomTexture.sample(linearSampler, sampleUV).rgb * uniforms.bloomIntensity;
    float3 color = sceneColor + bloomColor;

    float scanPhase = sampleUV.y * uniforms.resolution.y * uniforms.scanlineDensity;
    float scanline = 1.0 - uniforms.scanlineIntensity * 0.5 * (1.0 + sin(scanPhase * 3.14159265));

    float phosphorPhase = fract(sampleUV.x * uniforms.resolution.x / 3.0);
    float3 phosphorWeights = phosphorPhase < 0.333
        ? float3(1.0, 0.86, 0.86)
        : (phosphorPhase < 0.666 ? float3(0.86, 1.0, 0.86) : float3(0.86, 0.86, 1.0));
    float3 phosphorMask = mix(float3(1.0), phosphorWeights, uniforms.phosphorMaskIntensity);

    float vignette = 1.0
        - uniforms.vignetteIntensity
        * pow(clamp(length(centered) / 1.25, 0.0, 1.0), 2.2);

    color *= scanline * phosphorMask * vignette;
    return float4(clamp(color, 0.0, 1.0), 1.0);
}
