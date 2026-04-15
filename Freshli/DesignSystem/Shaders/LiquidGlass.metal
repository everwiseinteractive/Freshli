#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
half4 liquidGlass(float2 position, half4 color, float4 bounds, float density, float power) {
    // Normalize coordinates
    float2 uv = position / bounds.zw;

    // Create a refractive SDF (Signed Distance Field) effect
    // Simulates light bending through thick glass based on Figma 'Density'
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);

    // Calculate refraction offset
    float refraction = sin(dist * 10.0 - power) * (density * 0.05);

    // Chromatic Aberration (The 'Award-Winning' touch)
    half r = color.r;
    half g = color.g;
    half b = color.b;

    // Apply chromatic aberration offset scaled by refraction
    r = color.r + refraction * 0.1;
    b = color.b - refraction * 0.1;

    return half4(r, g, b, color.a);
}

// ──────────────────────────────────────────────────────────────────
// Gaze-Adaptive Bloom
//
// Localized bloom overlay driven by gaze proximity. When the user's
// gaze falls on a Liquid Glass element, this shader adds a subtle
// radial shimmer centered on the gaze point. The `bloomIntensity`
// parameter (0→1) controls the strength: 0 = invisible, 1 = full
// bloom. Combined with `liquidGlass`, this creates the "the UI
// responds to your mind" illusion.
//
// Parameters:
//   bounds:         float4 — view size (width, height, width, height)
//   gazeUV:         float2 — normalized gaze position on this view (0→1)
//   bloomIntensity: float  — proximity-driven bloom strength (0→1)
//   power:          float  — animated time phase (same as liquidGlass)
//   density:        float  — material density (same as liquidGlass)
// ──────────────────────────────────────────────────────────────────

[[ stitchable ]]
half4 gazeBloom(float2 position, half4 color, float4 bounds,
                float2 gazeUV, float bloomIntensity, float power, float density) {
    // Skip if no bloom
    if (bloomIntensity < 0.01) return color;

    float2 uv = position / bounds.zw;

    // Distance from gaze point — drives radial falloff
    float gazeDist = distance(uv, gazeUV);

    // Soft Gaussian-style falloff: tight inner glow + wider halo
    float innerGlow = exp(-gazeDist * gazeDist * 28.0);  // Sharp inner ring
    float outerHalo = exp(-gazeDist * gazeDist * 8.0);   // Soft outer halo

    // Animated shimmer: sine wave radiating from gaze point
    // Uses the same phase as liquidGlass for visual coherence
    float shimmer = sin(gazeDist * 16.0 - power * 2.5) * 0.5 + 0.5;
    shimmer *= outerHalo;

    // Combine: inner glow is steady, outer shimmer pulses
    float bloom = (innerGlow * 0.7 + shimmer * 0.3) * bloomIntensity;

    // Tint with a subtle warm white + density-scaled green channel boost
    // Heavy glass blooms warm, light glass blooms cool/airy
    half warmth = half(density * 3.0);
    half3 bloomColor = half3(
        0.92h + warmth * 0.08h,   // R: warm bias for heavy glass
        0.96h + warmth * 0.04h,   // G: always bright
        1.00h - warmth * 0.05h    // B: cool bias for light glass
    );

    // Chromatic bloom: slight RGB shift at the edges of the glow
    float chromaEdge = outerHalo * (1.0 - innerGlow) * bloomIntensity;
    half3 chromaShift = half3(
        half(chromaEdge * 0.015),
        0.0h,
        half(-chromaEdge * 0.015)
    );

    // Additive blend: bloom adds light, never subtracts
    half3 result = color.rgb + half(bloom) * bloomColor * 0.35h + chromaShift;

    return half4(min(result, 1.0h), color.a);
}
