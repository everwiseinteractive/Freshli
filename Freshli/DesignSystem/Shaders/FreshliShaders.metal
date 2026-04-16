#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ──────────────────────────────────────────────────────────
// Freshli — App-Wide Metal Shader Library (MSL 3.2+)
// GPU-accelerated visual effects used throughout the app via
// SwiftUI .colorEffect / .layerEffect / .distortionEffect.
// All shaders marked [[ stitchable ]] for SwiftUI integration.
//
// Design principles:
//   • half precision throughout for Apple GPU efficiency
//   • saturate() on all outputs — prevents colour overflow
//   • Additive glow tuned for "too little noise, too much depth"
//   • Every shader is safe for chained .colorEffect() pipelines
// ──────────────────────────────────────────────────────────


// ═══════════════════════════════════════════════════════════
// MARK: - GPU Shimmer Sweep
// Premium diagonal shimmer for loading placeholders (PSShimmerView)
// and impact cards. Replaces CPU LinearGradient overlay.
// Inputs: position, color, size, phase (0→1 sweep position)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 gpuShimmer(float2 position, half4 color, float2 size, float phase) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // Diagonal band position (rotated ~30°)
    float diag = uv.x * 0.85 + uv.y * 0.53;

    // Map phase (-0.3 → 1.3) to band center
    float bandCenter = phase;
    float dist = abs(diag - bandCenter);

    // Soft gaussian-like band with wider reach
    float shimmer = exp(-dist * dist / 0.012);

    // Core bright highlight
    float core = exp(-dist * dist / 0.003) * 0.6;

    // Total highlight intensity
    float highlight = shimmer * 0.18 + core;

    // Brighten the existing pixel
    half3 result = color.rgb + half3(highlight);

    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Freshness Ring Glow
// Dynamic halo around circular progress rings.
// Produces a breathing outer glow that follows the ring arc.
// Inputs: position, color, size, progress (0→1), time, glowColor (rgb)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 freshnessGlow(float2 position, half4 color, float2 size,
                     float progress, float time,
                     float glowR, float glowG, float glowB) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 center = size * 0.5;
    float2 delta = position - center;
    float dist = length(delta);
    float radius = min(size.x, size.y) * 0.5;

    // Angle from top (12 o'clock)
    float angle = atan2(delta.x, -delta.y); // 0 at top, CW positive
    float normAngle = (angle + M_PI_F) / (2.0 * M_PI_F); // 0→1

    // How far along the progress arc this pixel is
    float arcEnd = progress;
    float inArc = smoothstep(arcEnd + 0.01, arcEnd - 0.02, normAngle);

    // Ring proximity (glow falls off from the ring edge)
    float ringDist = abs(dist - radius * 0.88);
    float proximity = exp(-ringDist * ringDist / (radius * radius * 0.008));

    // Breathing pulse
    float breathe = sin(time * 2.0) * 0.5 + 0.5;

    // Glow intensity — strongest at the leading edge of the arc
    float edgeBoost = smoothstep(arcEnd - 0.08, arcEnd, normAngle) *
                      smoothstep(arcEnd + 0.02, arcEnd, normAngle);

    float glow = proximity * inArc * (0.3 + breathe * 0.15) +
                 proximity * edgeBoost * 0.5;

    // Compose glow color onto existing pixels
    half3 glowColor = half3(glowR, glowG, glowB);
    half3 result = color.rgb + glowColor * half(glow);

    return saturate(half4(result, color.a + half(glow * 0.4)));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Expiry Pulse
// Subtle pulsing glow for "Expiring Soon" and "Expired" badges.
// The pulse is a soft radial gradient that breathes.
// Inputs: position, color, size, time, pulseR/G/B
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 expiryPulse(float2 position, half4 color, float2 size, float time,
                   float pulseR, float pulseG, float pulseB) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);

    // Pulsing envelope
    float pulse = sin(time * 3.0) * 0.5 + 0.5; // 0→1 at 1.5 Hz

    // Soft radial glow, stronger when pulsing
    float glow = (1.0 - smoothstep(0.0, 0.55, dist)) * (0.08 + pulse * 0.12);

    half3 pulseColor = half3(pulseR, pulseG, pulseB);
    half3 result = color.rgb + pulseColor * half(glow);

    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Hero Gradient (Animated)
// Rich animated gradient for the HomeView curved header.
// Multiple layered sine waves create organic color movement.
// Inputs: position, color, size, time
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 heroGradient(float2 position, half4 color, float2 size, float time) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // Slow organic wave layers
    float wave1 = sin(uv.x * 3.0 + time * 0.3) * cos(uv.y * 2.5 + time * 0.25);
    float wave2 = sin(uv.y * 2.0 - time * 0.35) * cos(uv.x * 1.5 + time * 0.4);
    float wave3 = sin((uv.x + uv.y) * 2.2 + time * 0.2);

    float combined = (wave1 + wave2 + wave3) * 0.33;
    float t = combined * 0.5 + 0.5; // 0→1

    // Freshli green palette — dark forest → primary green → bright
    float3 deepGreen = float3(0.05, 0.31, 0.18);   // #0D4F2E
    float3 midGreen  = float3(0.09, 0.64, 0.29);   // #16A34A (headerGreen)
    float3 brightGreen = float3(0.13, 0.77, 0.37);  // #22C55E (primaryGreen)
    float3 accentTeal = float3(0.08, 0.72, 0.65);   // #14B8A6 (accentTeal)

    // 4-stop gradient — branch-free smoothstep blending to avoid
    // SIMD warp divergence at palette transition boundaries.
    // Each band overlaps via smoothstep; pixels near boundaries
    // compute a smooth blend instead of diverging into if/else paths.
    float b1 = smoothstep(0.0,  0.30, t);  // deepGreen → midGreen
    float b2 = smoothstep(0.25, 0.60, t);  // midGreen → brightGreen
    float b3 = smoothstep(0.55, 0.85, t);  // brightGreen → accentTeal
    float b4 = smoothstep(0.80, 1.00, t);  // accentTeal → midGreen (wrap)

    float3 rgb = deepGreen;
    rgb = mix(rgb, midGreen,     b1);
    rgb = mix(rgb, brightGreen,  b2);
    rgb = mix(rgb, accentTeal,   b3);
    rgb = mix(rgb, midGreen,     b4);

    // Vertical darkening toward bottom (natural shadow)
    rgb *= (1.0 - uv.y * 0.2);

    // Subtle vignette at edges
    float2 vc = (uv - 0.5) * 2.0;
    float vignette = 1.0 - dot(vc, vc) * 0.15;
    rgb *= clamp(vignette, 0.6, 1.0);

    // Overlay onto existing color (preserves alpha)
    half3 result = half3(rgb) * 0.85 + color.rgb * 0.15;
    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Card Glass Effect
// Subtle glass refraction overlay for premium card surfaces.
// Adds depth with a soft chromatic edge and light diffusion.
// Inputs: position, color, size, time, intensity (0→1)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 cardGlass(float2 position, half4 color, float2 size, float time, float intensity) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // Soft moving caustic pattern
    float caustic1 = sin(uv.x * 8.0 + time * 0.5) * cos(uv.y * 6.0 - time * 0.4);
    float caustic2 = cos(uv.x * 5.0 - time * 0.3) * sin(uv.y * 7.0 + time * 0.45);
    float caustic = (caustic1 + caustic2) * 0.5;

    // Only show caustic as subtle light
    float highlight = max(caustic, 0.0) * intensity * 0.06;

    // Top edge light (simulates overhead light source)
    float topLight = (1.0 - uv.y) * 0.03 * intensity;

    // Edge darkening for depth
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float edgeShadow = smoothstep(0.0, 0.15, edgeDist) * 0.02 * intensity;

    half3 result = color.rgb + half3(highlight + topLight + edgeShadow);
    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Impact Mesh Plasma
// Animated plasma for Impact Dashboard and Weekly Wrap backgrounds.
// More vivid than aurora — multiple color bands shift slowly.
// Inputs: position, color, size, time, intensityMix (0→1)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 impactPlasma(float2 position, half4 color, float2 size, float time, float intensityMix) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;
    float2 p = (uv - 0.5) * 2.0;

    // Multi-frequency plasma
    float n1 = sin(p.x * 2.5 + time * 0.25) * cos(p.y * 3.0 + time * 0.3);
    float n2 = sin(p.y * 1.8 - time * 0.35) * cos(p.x * 2.2 + time * 0.28);
    float n3 = cos(length(p) * 3.0 - time * 0.4);
    float n4 = sin((p.x - p.y) * 1.5 + time * 0.22);

    float plasma = (n1 + n2 + n3 + n4) * 0.25;
    float t = plasma * 0.5 + 0.5;

    // Color palette — Freshli sustainability greens with teal accents
    float3 col1 = float3(0.94, 0.99, 0.96); // Very light green-white
    float3 col2 = float3(0.86, 0.99, 0.89); // green-50
    float3 col3 = float3(0.80, 0.96, 0.86); // green-100 ish
    float3 col4 = float3(0.08, 0.72, 0.65); // accentTeal
    float3 col5 = float3(0.13, 0.77, 0.37); // primaryGreen

    // 5-stop palette — branch-free smoothstep blending to avoid
    // SIMD warp divergence on per-pixel color band transitions.
    float p1 = smoothstep(0.0,  0.25, t);
    float p2 = smoothstep(0.20, 0.50, t);
    float p3 = smoothstep(0.45, 0.75, t);
    float p4 = smoothstep(0.70, 1.00, t);

    float3 rgb = col1;
    rgb = mix(rgb, col2, p1);
    rgb = mix(rgb, col3, p2);
    rgb = mix(rgb, col4, p3);
    rgb = mix(rgb, col5, p4);

    // Vignette
    float vignette = 1.0 - length(p) * 0.3;
    vignette = clamp(vignette, 0.0, 1.0);
    rgb *= vignette;

    // Blend with existing color based on intensity
    half3 result = mix(color.rgb, half3(rgb), half(intensityMix * 0.35));
    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Celebration Radiance
// Radial glow burst for celebration overlays.
// Emanates from center with color-shifting halo rings.
// Inputs: position, color, size, time, intensity,
//         glowR/G/B (core glow color)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 celebrationRadiance(float2 position, half4 color, float2 size, float time,
                           float intensity,
                           float glowR, float glowG, float glowB) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 center = size * 0.5;
    float2 delta = position - center;
    float dist = length(delta) / min(size.x, size.y);

    // Expanding ring wave
    float wave = sin(dist * 12.0 - time * 5.0) * 0.5 + 0.5;
    float ringGlow = wave * exp(-dist * 3.0) * intensity;

    // Central radial glow
    float centralGlow = exp(-dist * dist * 6.0) * intensity * 0.8;

    // Subtle color shifting along angle
    float angle = atan2(delta.y, delta.x);
    float hueShift = sin(angle * 2.0 + time * 1.5) * 0.15;

    half3 glowColor = half3(glowR + hueShift, glowG, glowB - hueShift * 0.5);
    half3 result = color.rgb + glowColor * half(ringGlow + centralGlow);

    return saturate(half4(result, color.a + half(centralGlow * 0.3)));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Streak Flame Glow
// Warm pulsing fire glow behind the streak flame icon.
// Inputs: position, color, size, time, streakDays (0→7+)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 streakFlameGlow(float2 position, half4 color, float2 size, float time,
                       float streakDays) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;
    float2 center = float2(0.5, 0.45); // Slightly above center (flame rises)
    float2 delta = uv - center;
    float dist = length(delta);

    // Flickering flame shape (narrower at top, wider at base)
    float flameShape = delta.y * 0.8; // Pull upward
    float adjustedDist = length(float2(delta.x * 1.3, delta.y - flameShape));

    // Multi-frequency flicker
    float flicker = sin(time * 8.0) * 0.1 + sin(time * 13.0) * 0.06 +
                    sin(time * 5.0 + uv.x * 3.0) * 0.08;

    // Intensity scales with streak length
    float streakIntensity = clamp(streakDays / 7.0, 0.3, 1.0);

    // Core glow
    float glow = exp(-adjustedDist * adjustedDist / 0.06) *
                 (0.6 + flicker) * streakIntensity;

    // Outer aura
    float aura = exp(-dist * dist / 0.12) * 0.3 * streakIntensity;

    // Warm fire colors: orange → amber → yellow at core
    half3 outerColor = half3(0.97, 0.45, 0.09); // orange
    half3 innerColor = half3(0.98, 0.75, 0.15); // amber-yellow
    half3 fireColor = mix(outerColor, innerColor, half(glow));

    half3 result = color.rgb + fireColor * half(glow + aura);
    return saturate(half4(result, color.a + half(glow * 0.2)));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Ambient Particles
// GPU-computed floating particle field for backgrounds.
// Particles drift upward like fireflies / spores.
// Inputs: position, color, size, time, density (1→5), brightness
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 ambientParticles(float2 position, half4 color, float2 size, float time,
                        float density, float brightness) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    float totalGlow = 0.0;

    // Generate multiple pseudo-random particles
    for (int i = 0; i < int(density * 8.0); i++) {
        // Pseudo-random seed per particle
        float fi = float(i);
        float seed1 = fract(sin(fi * 127.1) * 43758.5453);
        float seed2 = fract(cos(fi * 311.7) * 19283.1749);
        float seed3 = fract(sin(fi * 78.233) * 91282.3719);

        // Particle position — drifts slowly
        float px = seed1 + sin(time * (0.1 + seed3 * 0.15) + fi) * 0.08;
        float py = fract(seed2 - time * (0.02 + seed3 * 0.03)); // Drift upward

        float2 particlePos = float2(fract(px), py);
        float d = length(uv - particlePos);

        // Size variation
        float particleSize = 0.004 + seed3 * 0.006;

        // Twinkle
        float twinkle = sin(time * (3.0 + seed1 * 4.0) + fi * 2.0) * 0.5 + 0.5;

        float glow = exp(-d * d / (particleSize * particleSize)) * twinkle;
        totalGlow += glow;
    }

    totalGlow = clamp(totalGlow * brightness, 0.0, 0.4);

    // Soft green-white particles
    half3 particleColor = half3(0.7, 1.0, 0.8);
    half3 result = color.rgb + particleColor * half(totalGlow);

    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Button Press Ripple (Legacy — additive highlight only)
// Concentric ripple emanating from press point.
// Inputs: position, color, size, time (since press), progress (0→1)
// Kept for backward-compat; new code uses liquidGlassRipple below.
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 buttonRipple(float2 position, half4 color, float2 size, float progress) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 center = size * 0.5;
    float2 delta = position - center;
    float dist = length(delta) / max(size.x, size.y);

    // Expanding ring
    float ringRadius = progress * 0.7;
    float ringDist = abs(dist - ringRadius);
    float ring = exp(-ringDist * ringDist / 0.002) * (1.0 - progress);

    // Fill behind ring
    float fill = smoothstep(ringRadius + 0.02, ringRadius - 0.05, dist) *
                 (1.0 - progress) * 0.06;

    float highlight = ring * 0.25 + fill;

    half3 result = color.rgb + half3(highlight);
    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Liquid Glass Refraction Ripple (Metal 4 — distortion)
// GPU vertex displacement shader for real refraction on button press.
// Uses .distortionEffect — displaces pixel sample positions to create
// a spreading ripple that refracts content beneath the glass surface.
//
// Parameters:
//   position        — current pixel position (from SwiftUI)
//   size            — view size
//   progress        — 0→1 ripple expansion progress
//   refractiveIndex — FLMaterialDensity token (1.0 low, 1.33 med, 1.52 high)
//   centerX/Y       — touch origin (normalized 0→1, default 0.5/0.5)
//
// The ripple has three zones:
//   1. Leading ring — sharp refraction at the wavefront
//   2. Inner wake — softer trailing distortion behind the ring
//   3. Caustic shimmer — fine displacement jitter for glass texture
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
float2 liquidGlassRipple(float2 position, float2 size,
                          float progress, float refractiveIndex,
                          float centerX, float centerY) {
    if (size.x < 1.0 || size.y < 1.0) return position;
    // ── Normalized coordinates ──
    float2 center = float2(centerX, centerY) * size;
    float2 delta = position - center;
    float dist = length(delta);
    float maxDim = max(size.x, size.y);

    // Normalized distance from touch origin
    float normDist = dist / maxDim;

    // ── Refraction strength from material density ──
    // refractiveIndex: 1.0 (low/air) → 1.33 (med/water) → 1.52 (high/glass)
    // Map to displacement amplitude: stronger index = more distortion
    float refrStrength = (refractiveIndex - 1.0) * 2.8;

    // ── 1. Leading ring — the expanding wavefront ──
    float ringRadius = progress * 0.65;
    float ringDist = normDist - ringRadius;
    // Sharp gaussian ring with direction-aware displacement
    float ringAmplitude = exp(-ringDist * ringDist / 0.0015) * (1.0 - progress);

    // ── 2. Inner wake — trailing refraction behind the ring ──
    float wakeMask = smoothstep(ringRadius + 0.01, ringRadius - 0.12, normDist);
    float wakeDecay = (1.0 - progress * 0.7);
    float wakeAmplitude = wakeMask * wakeDecay * 0.35;

    // ── 3. Caustic shimmer — fine-grain glass texture jitter ──
    float causticFreq = 28.0 + progress * 12.0;
    float2 causticOffset = float2(
        sin(position.y / maxDim * causticFreq + progress * 6.28) *
        cos(position.x / maxDim * causticFreq * 0.7),
        cos(position.x / maxDim * causticFreq * 0.8 + progress * 4.71) *
        sin(position.y / maxDim * causticFreq * 0.6)
    );
    float causticStrength = wakeMask * (1.0 - progress) * 0.2;

    // ── Compose displacement ──
    float2 direction = dist > 0.001 ? delta / dist : float2(0.0, 1.0);

    float totalRadial = (ringAmplitude * 1.0 + wakeAmplitude) * refrStrength;
    float2 displacement = direction * totalRadial * maxDim * 0.012
                        + causticOffset * causticStrength * maxDim * 0.003 * refrStrength;

    // Scale down globally so it never feels excessive
    displacement *= 0.85;

    return position + displacement;
}


// ═══════════════════════════════════════════════════════════
// MARK: - Liquid Glass Ripple Color Pass (additive highlight companion)
// Paired .colorEffect that adds the visual ripple ring + specular
// highlight on top of the distortion. Applied AFTER the distortion
// pass to give the wavefront a visible bright edge.
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 liquidGlassRippleColor(float2 position, half4 color, float2 size,
                              float progress, float refractiveIndex,
                              float centerX, float centerY) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 center = float2(centerX, centerY) * size;
    float2 delta = position - center;
    float dist = length(delta);
    float maxDim = max(size.x, size.y);
    float normDist = dist / maxDim;

    float refrStrength = (refractiveIndex - 1.0) * 2.8;

    // Visible ring at the wavefront
    float ringRadius = progress * 0.65;
    float ringDist = normDist - ringRadius;
    float ring = exp(-ringDist * ringDist / 0.001) * (1.0 - progress);

    // Specular highlight behind the ring (glass caustic sheen)
    float specularMask = smoothstep(ringRadius + 0.01, ringRadius - 0.08, normDist);
    float specular = specularMask * (1.0 - progress) * 0.04;

    // Fresnel rim — brighter at edges for glass appearance
    float edgeDist = min(min(position.x / size.x, 1.0 - position.x / size.x),
                         min(position.y / size.y, 1.0 - position.y / size.y));
    float fresnelRim = (1.0 - smoothstep(0.0, 0.08, edgeDist)) * specularMask * 0.06;

    float highlight = (ring * 0.2 + specular + fresnelRim) * (0.5 + refrStrength * 0.5);

    half3 rippleResult = color.rgb + half3(highlight);
    return saturate(half4(rippleResult, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Weekly Wrap Background
// Animated gradient for the full-screen Weekly Wrap story view.
// Multi-color bands drift and morph slowly.
// Inputs: position, color, size, time,
//         c1R/G/B, c2R/G/B, c3R/G/B (three gradient colors)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 weeklyWrapBg(float2 position, half4 color, float2 size, float time,
                    float c1R, float c1G, float c1B,
                    float c2R, float c2G, float c2B,
                    float c3R, float c3G, float c3B) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;
    float2 p = (uv - 0.5) * 2.0;

    // Slow morphing blobs
    float blob1 = sin(p.x * 2.0 + time * 0.3) * cos(p.y * 1.8 + time * 0.25);
    float blob2 = cos(p.x * 1.5 - time * 0.2) * sin(p.y * 2.5 + time * 0.35);
    float blob3 = sin(length(p) * 2.5 - time * 0.4);

    float t1 = (blob1 * 0.5 + 0.5);
    float t2 = (blob2 * 0.5 + 0.5);
    float t3 = (blob3 * 0.5 + 0.5);

    float3 col1 = float3(c1R, c1G, c1B);
    float3 col2 = float3(c2R, c2G, c2B);
    float3 col3 = float3(c3R, c3G, c3B);

    // Blend three colors using blob weights
    float w1 = t1 * 0.4;
    float w2 = t2 * 0.35;
    float w3 = t3 * 0.25;
    float wTotal = w1 + w2 + w3;

    float3 rgb = (col1 * w1 + col2 * w2 + col3 * w3) / wTotal;

    // Darken at edges for vignette
    float vignette = 1.0 - length(p) * 0.25;
    vignette = clamp(vignette * vignette, 0.3, 1.0);
    rgb *= vignette;

    return saturate(half4(half3(rgb), 1.0h));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Subtle Noise Texture
// Adds film-grain-like noise to surfaces for tactile depth.
// Inputs: position, color, size, time, intensity (0→1)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 subtleNoise(float2 position, half4 color, float2 size, float time,
                   float intensity) {
    // Hash function for pseudo-random noise
    float2 p = position + float2(time * 100.0, time * 73.0);
    float noise = fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);

    // Center noise around 0 (some pixels brighter, some darker)
    float grain = (noise - 0.5) * intensity * 0.04;

    half3 result = color.rgb + half3(grain);
    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Chef Silhouette (Cooking Mode Background)
// Abstract luminous chef figure for the immersive CookingScreenView.
// Built from layered gaussian SDFs — toque, head, body, stirring arm.
// Five-phase 14s cycle: appear → stir → steam → sparkle → breathe.
// The figure is intentionally ethereal — soft, luminous shapes that
// suggest a chef rather than depicting one literally.
// Inputs: position, color, size, time, opacity (0→1 fade-in)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 chefSilhouette(float2 position, half4 color, float2 size, float time,
                      float opacity) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // ─── Phase cycling (14s total) ───
    // 0–2.5s   appear   — hat materialises first, body follows
    // 2–7s     stir     — spoon swings rhythmically
    // 4–10s    steam    — wisps rise from the cooking area
    // 9–12s    sparkle  — completion / plating sparkles
    // 12–14s   breathe  — gentle reset, loop
    float cycle    = fmod(time, 14.0);
    float appear   = smoothstep(0.0, 2.5, cycle);
    float stir     = smoothstep(2.0, 3.5, cycle) * (1.0 - smoothstep(6.5, 7.5, cycle));
    float steamPh  = smoothstep(4.0, 5.5, cycle) * (1.0 - smoothstep(9.5, 10.5, cycle));
    float sparklePh = smoothstep(9.0, 10.0, cycle) * (1.0 - smoothstep(12.0, 13.0, cycle));
    float breathe  = sin(time * 1.2) * 0.5 + 0.5;

    // ─── Chef Toque (hat) — the signature element ───
    float2 hatC = float2(0.50, 0.22);
    float hatD = length((uv - hatC) * float2(1.0, 1.4));
    float hat = exp(-hatD * hatD / 0.006);

    // Three pleat bumps across the top for that classic toque shape
    float p1 = exp(-length(uv - float2(0.44, 0.18)) * length(uv - float2(0.44, 0.18)) / 0.0018);
    float p2 = exp(-length(uv - float2(0.50, 0.16)) * length(uv - float2(0.50, 0.16)) / 0.0022);
    float p3 = exp(-length(uv - float2(0.56, 0.18)) * length(uv - float2(0.56, 0.18)) / 0.0018);
    hat = max(hat, max(p1, max(p2, p3)));

    // Hat band — the dark ribbon at the base of the toque
    float2 bandC = float2(0.50, 0.30);
    float bandX = abs(uv.x - bandC.x);
    float bandY = abs(uv.y - bandC.y);
    float band = smoothstep(1.0, 0.6, max(bandX / 0.065, bandY / 0.012));

    // ─── Head ───
    float2 headC = float2(0.50, 0.37);
    float headD = length((uv - headC) * float2(1.35, 1.0));
    float head = exp(-headD * headD / 0.0025);

    // ─── Body / Shoulders ───
    float2 bodyC = float2(0.50, 0.53);
    float bodyD = length((uv - bodyC) * float2(0.48, 0.82));
    float body = exp(-bodyD * bodyD / 0.022);

    // ─── Apron suggestion ───
    float2 apronC = float2(0.50, 0.60);
    float apronD = length((uv - apronC) * float2(0.62, 1.1));
    float apron = exp(-apronD * apronD / 0.013) * 0.55;

    // ─── Stirring arm + spoon ───
    float stirAngle = stir * sin(time * 2.8) * 0.38;
    float baseAng = -0.6 + stirAngle;
    float2 spBase = float2(0.64, 0.46);
    float2 spDir  = float2(cos(baseAng), sin(baseAng));
    float spLen   = 0.14;
    float2 pRel   = uv - spBase;
    float proj    = clamp(dot(pRel, spDir), 0.0, spLen);
    float spD     = length(pRel - spDir * proj);
    float spoon   = exp(-spD * spD / 0.00013) * (0.25 + stir * 0.75);

    // Spoon bowl (rounded end)
    float2 spTip = spBase + spDir * spLen;
    float bowlD  = length(uv - spTip);
    float bowl   = exp(-bowlD * bowlD / 0.00055) * (0.25 + stir * 0.75);

    // ─── Steam wisps — procedural rising curls ───
    float steam = 0.0;
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float s1 = fract(sin(fi * 127.1) * 43758.5453);
        float s2 = fract(cos(fi * 311.7) * 19283.1749);
        float s3 = fract(sin(fi * 78.233) * 91282.3719);

        float sx   = 0.37 + s1 * 0.26;
        float sy   = fract(0.72 - time * (0.022 + s2 * 0.018));
        float wob  = sin(time * 1.5 + fi * 2.3) * 0.028;
        float sSize = 0.003 + s3 * 0.005;

        float2 sp = float2(sx + wob, sy);
        float d   = length(uv - sp);
        float vF  = smoothstep(0.72, 0.48, sy) * smoothstep(0.10, 0.26, sy);
        steam    += exp(-d * d / sSize) * vF;
    }
    steam *= (0.20 + steamPh * 0.80);

    // ─── Sparkles — celebration / plating moment ───
    float sparkles = 0.0;
    if (sparklePh > 0.01) {
        for (int i = 0; i < 10; i++) {
            float fi = float(i);
            float sx = fract(sin(fi * 78.233) * 91282.3719);
            float sy = fract(cos(fi * 45.164) * 38291.7635);
            float twinkle = pow(sin(time * (5.0 + fi * 1.3) + fi * 2.0) * 0.5 + 0.5, 3.0);
            float2 sp = float2(0.25 + sx * 0.50, 0.14 + sy * 0.56);
            float d = length(uv - sp);
            sparkles += exp(-d * d / 0.00055) * twinkle;
        }
        sparkles *= sparklePh;
    }

    // ─── Compose all layers ───
    float chef = max(max(max(hat, band), max(head, body)),
                     max(apron, max(spoon, bowl)));

    // Glow intensities tuned for atmospheric presence —
    // visible through .thinMaterial glass but never dominant.
    // The chef is a soft luminous suggestion, not a bright figure.
    // "Too little visual noise and too much visual depth."
    float chefGlow    = chef    * (0.32 + breathe * 0.08) * appear;
    float steamGlow   = steam   * 0.22 * appear;
    float sparkleGlow = sparkles * 0.30;

    // Warm Freshli-green with gentle breathing colour shift
    half3 chefCol    = mix(half3(0.20, 0.75, 0.38), half3(0.35, 0.92, 0.52), half(breathe));
    half3 steamCol   = half3(0.48, 0.82, 0.56);
    half3 sparkleCol = half3(0.92, 1.0, 0.62);

    half op = half(opacity);
    half3 result = color.rgb
        + chefCol    * half(chefGlow)    * op
        + steamCol   * half(steamGlow)   * op
        + sparkleCol * half(sparkleGlow) * op;

    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Freshli Aura (Home Header Emitter)
// Themed particle emitter for the HomeView hero header.
// Replaces generic firefly dots with floating leaf shapes and
// seed/droplet particles — directly relevant to Freshli's
// food-rescue mission. Leaves use an almond SDF with gentle
// rotation; seeds are smaller, faster twinklers.
// Inputs: position, color, size, time
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 freshliAura(float2 position, half4 color, float2 size, float time) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;
    float totalGlow = 0.0;

    // ─── Floating Leaf Particles (almond SDF) ───
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        float s1 = fract(sin(fi * 127.1) * 43758.5453);
        float s2 = fract(cos(fi * 311.7) * 19283.1749);
        float s3 = fract(sin(fi * 78.233) * 91282.3719);

        // Drift upward with lateral sway
        float px = s1 + sin(time * (0.12 + s3 * 0.08) + fi * 1.8) * 0.055;
        float py = fract(s2 - time * (0.012 + s3 * 0.015));
        float2 leafPos = float2(fract(px), py);
        float2 delta   = uv - leafPos;

        // Rotate the leaf shape over time
        float angle = time * (0.25 + s1 * 0.35) + fi;
        float ca = cos(angle), sa = sin(angle);
        float2 rot = float2(ca * delta.x - sa * delta.y,
                            sa * delta.x + ca * delta.y);

        // Almond / leaf SDF — intersection of two offset circles
        float leafSz = 0.010 + s3 * 0.007;
        float off    = leafSz * 0.45;
        float d1 = length(rot - float2(0.0, off)) - leafSz;
        float d2 = length(rot + float2(0.0, off)) - leafSz;
        float leafSDF = max(d1, d2);

        float twinkle  = sin(time * (1.5 + s1 * 2.5) + fi * 1.2) * 0.5 + 0.5;
        float leafGlow = smoothstep(0.002, -0.001, leafSDF) * twinkle;

        // Fade near top/bottom edges
        float vFade = smoothstep(0.0, 0.08, py) * smoothstep(1.0, 0.92, py);
        totalGlow += leafGlow * 0.10 * vFade;
    }

    // ─── Seed / Droplet Particles (smaller, faster) ───
    for (int i = 0; i < 8; i++) {
        float fi = float(i) + 30.0;
        float s1 = fract(sin(fi * 127.1) * 43758.5453);
        float s2 = fract(cos(fi * 311.7) * 19283.1749);
        float s3 = fract(sin(fi * 78.233) * 91282.3719);

        float px = s1 + sin(time * (0.18 + s3 * 0.12)) * 0.035;
        float py = fract(s2 - time * (0.02 + s3 * 0.025));
        float d  = length(uv - float2(fract(px), py));

        float dropSz  = 0.0015 + s3 * 0.0025;
        float twinkle = sin(time * (3.0 + s1 * 3.5) + fi) * 0.5 + 0.5;
        float glow    = exp(-d * d / (dropSz * dropSz)) * twinkle;

        float vFade = smoothstep(0.0, 0.06, py) * smoothstep(1.0, 0.94, py);
        totalGlow += glow * 0.07 * vFade;
    }

    totalGlow = clamp(totalGlow, 0.0, 0.32);

    // Bright leaf-green with slight warmth
    half3 leafColor = half3(0.58, 1.0, 0.68);
    half3 result = color.rgb + leafColor * half(totalGlow);

    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Intent Glow (Apple Intelligence Adaptive Surface)
// Gentle ambient glow + travelling highlight for UI elements
// predicted as the user's next interaction target.
// The effect breathes naturally, drawing attention without
// being distracting — a "living" surface that responds to AI.
// Inputs: position, color, size, time,
//         intensity (0→1), glowR/G/B
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 intentGlow(float2 position, half4 color, float2 size, float time,
                  float intensity, float glowR, float glowG, float glowB) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float2 delta  = uv - center;
    float  dist   = length(delta);

    // Breathing rhythm — organic 2.5s cycle
    float breathe = sin(time * 2.5) * 0.5 + 0.5;
    float pulse   = breathe * clamp(intensity, 0.0, 1.0);

    // Inner radial warmth
    float innerGlow = exp(-dist * dist / 0.16) * pulse * 0.10;

    // Edge swell — luminous ring at element perimeter
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float edgeGlow = (1.0 - smoothstep(0.0, 0.08, edgeDist)) * pulse * 0.14;

    // Travelling highlight — slowly orbits the border
    float angle = atan2(delta.y, delta.x);
    float highlight = smoothstep(0.72, 1.0, cos(angle - time * 1.4)) * 0.12 * pulse;

    // Secondary counter-rotating spot
    float spot2 = smoothstep(0.82, 1.0, cos(angle + time * 0.9 + 3.14159)) * 0.06 * pulse;

    float total = innerGlow + edgeGlow + highlight + spot2;

    half3 glowColor = half3(glowR, glowG, glowB);
    half3 result = color.rgb + glowColor * half(total);

    return saturate(half4(result, color.a + half(total * 0.25)));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Liquid Glass Surface
// Brings the splash Liquid Glass aesthetic to everyday cards
// and section headers. Adds Fresnel rim brightening, moving
// caustics, subtle chromatic edge shift, and a directional
// specular highlight — all within a single .colorEffect pass.
// Inputs: position, color, size, time, intensity (0→1)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 liquidGlassSurface(float2 position, half4 color, float2 size,
                          float time, float intensity) {
    float2 uv     = position / size;
    float2 center = float2(0.5, 0.5);
    float2 delta  = uv - center;

    float gi = clamp(intensity, 0.0, 1.0);

    // ── Fresnel rim brightening ──
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float fresnel  = pow(1.0 - smoothstep(0.0, 0.12, edgeDist), 2.6) * gi * 0.14;

    // ── Moving caustics — two interfering wave fronts ──
    float c1 = sin(uv.x * 12.0 + time * 0.55) * cos(uv.y * 10.0 - time * 0.48);
    float c2 = cos(uv.x * 8.5 - time * 0.38)  * sin(uv.y * 11.0 + time * 0.52);
    float caustic = pow(clamp(c1 * c2 * 0.5 + 0.5, 0.0, 1.0), 6.0) * 0.07 * gi;

    // ── Directional specular — light from upper-right ──
    float2 surfNorm = normalize(delta + float2(0.001, 0.001));
    float2 lightDir = normalize(float2(0.38, -0.58));
    float spec = pow(clamp(dot(surfNorm, lightDir), 0.0, 1.0), 14.0) * 0.09 * gi;

    // ── Top-surface overhead light ──
    float topLight = (1.0 - uv.y) * 0.035 * gi;

    // ── Chromatic edge shift (faked per-channel offset) ──
    float chromaAmt = (1.0 - smoothstep(0.0, 0.10, edgeDist)) * 0.004 * gi;
    float redShift  =  sin(uv.x * 22.0 + time * 0.32) * chromaAmt;
    float blueShift =  cos(uv.y * 19.0 - time * 0.42) * chromaAmt;

    // ── Compose ──
    float shared = caustic + fresnel + spec + topLight;
    half3 result;
    result.r = color.r + half(shared + redShift);
    result.g = color.g + half(shared);
    result.b = color.b + half(shared + blueShift);

    return saturate(half4(result, color.a));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Predictive Surface (Apple Intelligence Adaptive Card)
// A geometry-morphing, glow-shifting shader for the Predictive
// Surface card on the Home screen. When the Foundation Models
// engine predicts the user's next action, this shader makes
// the card come alive:
//   • Soft radial aura that breathes with confidence level
//   • Wave-based edge distortion (geometry "morphing")
//   • Flowing gradient that shifts toward the predicted
//     action's colour space
//   • Orbiting light filament along the card perimeter
//
// Inputs: position, color, size, time,
//         confidence (0→1), glowR/G/B
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 predictiveSurface(float2 position, half4 color, float2 size, float time,
                         float confidence, float glowR, float glowG, float glowB) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float2 delta = uv - center;
    float dist = length(delta);
    float angle = atan2(delta.y, delta.x);

    float ci = clamp(confidence, 0.0, 1.0);

    // ── 1. Organic breathing rhythm ──
    float breathA = sin(time * 2.0) * 0.5 + 0.5;
    float breathB = sin(time * 1.2 + 1.7) * 0.5 + 0.5;
    float pulse = mix(breathA, breathB, 0.4) * ci;

    // ── 2. Radial aura — warm inner glow ──
    float innerGlow = exp(-dist * dist / 0.18) * pulse * 0.12;

    // ── 3. Edge morphing — geometry comes alive ──
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float edgeWave = sin(angle * 5.0 + time * 2.8) * 0.5 + 0.5;
    float morphGlow = (1.0 - smoothstep(0.0, 0.06 + ci * 0.04, edgeDist))
                    * edgeWave * pulse * 0.16;

    // ── 4. Orbiting light filament ──
    float orbit = smoothstep(0.75, 1.0, cos(angle - time * 1.1)) * ci * 0.14;
    float orbit2 = smoothstep(0.85, 1.0, cos(angle + time * 0.7 + 3.14159)) * ci * 0.07;

    // ── 5. Flowing gradient shift ──
    float diagFlow = (uv.x + uv.y) * 0.5 + sin(time * 0.6) * 0.15;
    float flowMask = smoothstep(0.3, 0.7, diagFlow) * ci * 0.06;

    // ── 6. Micro-caustic shimmer ──
    float c1 = sin(uv.x * 18.0 + time * 0.7) * cos(uv.y * 14.0 - time * 0.5);
    float c2 = cos(uv.x * 11.0 - time * 0.4) * sin(uv.y * 16.0 + time * 0.6);
    float caustic = pow(clamp(c1 * c2 * 0.5 + 0.5, 0.0, 1.0), 8.0) * 0.04 * ci;

    // ── Compose ──
    float total = innerGlow + morphGlow + orbit + orbit2 + flowMask + caustic;

    half3 glowColor = half3(glowR, glowG, glowB);
    half3 result2 = color.rgb + glowColor * half(total);
    float alphaBoost = (morphGlow + orbit) * 0.3;

    return saturate(half4(result2, color.a + half(alphaBoost)));
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Ray-Traced Dynamic Shadows
// Simulates soft shadows cast from UI elements onto the Liquid Glass
// background. Shadow direction, softness, and color adapt to the
// device's ambient light level in real-time.
//
// Architecture:
//   - Per-pixel shadow sampling with Poisson disk distribution
//   - Shadow penumbra scales with element elevation (higher = softer)
//   - Ambient light drives: shadow opacity, penumbra spread, color temp
//   - OLED-black mode: elements emit a soft warm glow instead of casting
//     traditional shadows (self-luminous UI on true-black background)
//   - High-key mode: shadows nearly vanish, replaced by strong specular
//
// Inputs:
//   position: pixel coordinates
//   color: source pixel color
//   size: view dimensions
//   lightDirX, lightDirY: normalized light direction (-1→+1)
//   elevation: element Z-height (maps to shadow offset + blur)
//   ambientBrightness: 0.0 (dark room) → 1.0 (bright room)
//   shadowR, shadowG, shadowB: shadow tint color
//   time: elapsed seconds for subtle animation
// ═══════════════════════════════════════════════════════════════

[[stitchable]] half4 rayTracedShadow(
    float2 position,
    half4 color,
    float2 size,
    float lightDirX,
    float lightDirY,
    float elevation,
    float ambientBrightness,
    float shadowR,
    float shadowG,
    float shadowB,
    float time
) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // ── 1. Shadow offset from light direction + elevation ──
    // Higher elevation = longer shadow, offset further from element
    float shadowLength = elevation * 0.015;
    float2 shadowDir = float2(lightDirX, lightDirY) * shadowLength;

    // UV of the shadow origin (where the light would project this pixel)
    float2 shadowUV = uv - shadowDir;

    // ── 2. Soft penumbra via multi-sample disk ──
    // Poisson disk offsets for smooth penumbra (8 samples)
    // Scaled by elevation — higher elements cast softer shadows
    float penumbraSize = elevation * 0.008 * (1.0 + ambientBrightness * 0.5);

    const int SAMPLES = 8;
    float2 poissonDisk[8] = {
        float2(-0.94201624, -0.39906216),
        float2( 0.94558609, -0.76890725),
        float2(-0.09418410, -0.92938870),
        float2( 0.34495938,  0.29387760),
        float2(-0.91588581,  0.45771432),
        float2(-0.81544232, -0.87912464),
        float2(-0.38277543,  0.27676845),
        float2( 0.97484398,  0.75648379)
    };

    float shadowAccum = 0.0;
    for (int i = 0; i < SAMPLES; i++) {
        float2 sampleUV = shadowUV + poissonDisk[i] * penumbraSize;
        // Inside the element bounds → shadow contribution
        float inside = step(0.0, sampleUV.x) * step(sampleUV.x, 1.0)
                     * step(0.0, sampleUV.y) * step(sampleUV.y, 1.0);
        // Distance-based falloff from shadow center
        float dist = length(sampleUV - uv);
        float falloff = exp(-dist * dist / (penumbraSize * 4.0 + 0.001));
        shadowAccum += inside * falloff;
    }
    shadowAccum /= float(SAMPLES);

    // ── 3. Ambient-adaptive shadow intensity ──
    // Dark rooms: strong, warm-tinted shadows (OLED glow effect)
    // Bright rooms: faint, cool shadows (high-key wash)
    float baseShadowAlpha = mix(0.45, 0.08, ambientBrightness);
    float shadowAlpha = shadowAccum * baseShadowAlpha;

    // ── 4. OLED-black self-luminous glow ──
    // When ambientBrightness < 0.15, elements emit a soft glow
    // instead of casting traditional shadows
    float oledGlow = 0.0;
    if (ambientBrightness < 0.20) {
        float glowStrength = (0.20 - ambientBrightness) / 0.20;  // 1.0 at pitch black, 0 at 0.20
        float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        // Soft radial glow emanating from the element edges
        float edgeGlow = exp(-edgeDist * edgeDist / 0.004);
        // Subtle breathing animation
        float breathe = sin(time * 1.5) * 0.15 + 0.85;
        oledGlow = edgeGlow * glowStrength * breathe * 0.3;
    }

    // ── 5. High-key specular flash ──
    // When ambientBrightness > 0.70, add a bright specular highlight
    float specular = 0.0;
    if (ambientBrightness > 0.65) {
        float specStrength = (ambientBrightness - 0.65) / 0.35;
        // Specular hotspot moves with light direction
        float2 specPos = float2(0.5 - lightDirX * 0.3, 0.3 - lightDirY * 0.2);
        float specDist = length(uv - specPos);
        specular = exp(-specDist * specDist / 0.015) * specStrength * 0.35;
    }

    // ── 6. Compose ──
    half3 shadowTint = half3(shadowR, shadowG, shadowB);

    // Shadow darkens the pixel
    half3 shadowed = color.rgb * half(1.0 - shadowAlpha)
                   + shadowTint * half(shadowAlpha * 0.3);

    // OLED glow adds warm light from edges
    half3 withGlow = shadowed + half3(0.13, 0.77, 0.37) * half(oledGlow);

    // Specular adds bright white highlight
    half3 withSpecular = withGlow + half3(1.0, 0.98, 0.96) * half(specular);

    return half4(saturate(withSpecular), color.a);
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Ambient Adaptive Glass
// Modifies the Liquid Glass surface appearance based on ambient light.
// Dark room → warm OLED inner glow; bright room → crisp specular sheen.
//
// Inputs:
//   position, color, size: standard stitchable params
//   ambientBrightness: 0→1 from AmbientLightService
//   time: elapsed seconds
//   tintR, tintG, tintB: brand color tint
// ═══════════════════════════════════════════════════════════════

[[stitchable]] half4 ambientAdaptiveGlass(
    float2 position,
    half4 color,
    float2 size,
    float ambientBrightness,
    float time,
    float tintR,
    float tintG,
    float tintB
) {
    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // Edge distance for rim effects
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float edgeNorm = smoothstep(0.0, 0.08, edgeDist);

    if (ambientBrightness < 0.20) {
        // ── OLED-Black Mode ──
        // Soft warm glow emanates from the glass edges
        float darkness = (0.20 - ambientBrightness) / 0.20;

        // Edge glow — Fresnel-like rim light
        float rimGlow = (1.0 - edgeNorm) * darkness * 0.35;
        float breathe = sin(time * 1.2) * 0.1 + 0.9;
        rimGlow *= breathe;

        // Inner warmth — very subtle center glow
        float centerDist = length(uv - float2(0.5));
        float innerWarm = exp(-centerDist * centerDist / 0.15) * darkness * 0.06;

        half3 warmTint = half3(tintR, tintG, tintB);
        half3 result = color.rgb + warmTint * half(rimGlow + innerWarm);
        return half4(saturate(result), color.a);

    } else if (ambientBrightness > 0.70) {
        // ── High-Key Mode ──
        // Crisp glass sheen with strong specular
        float brightness = (ambientBrightness - 0.70) / 0.30;

        // Top-edge highlight (simulates overhead light)
        float topHighlight = (1.0 - smoothstep(0.0, 0.15, uv.y)) * brightness * 0.25;

        // Diagonal specular sweep
        float diagAngle = (uv.x * 0.6 + uv.y * 0.4);
        float sweep = smoothstep(0.35, 0.50, diagAngle)
                    * (1.0 - smoothstep(0.50, 0.65, diagAngle));
        float specSweep = sweep * brightness * 0.18;

        // Glass edge reflection
        float edgeReflect = (1.0 - edgeNorm) * brightness * 0.12;

        half3 highlight = half3(1.0, 0.99, 0.97);
        half3 result = color.rgb + highlight * half(topHighlight + specSweep + edgeReflect);
        return half4(saturate(result), color.a);

    } else {
        // ── Neutral Mode ──
        // Subtle glass surface with gentle Fresnel rim
        float neutralRim = (1.0 - edgeNorm) * 0.04;
        half3 result = color.rgb + half3(1.0) * half(neutralRim);
        return half4(saturate(result), color.a);
    }
}


// ═══════════════════════════════════════════════════════════
// MARK: - Tab Melt Dissolve (Tab Transition)
// Noise-based dissolve for tab transitions. Pixels melt away
// based on 2D value noise compared against a progress threshold,
// with a luminous Freshli-green edge glow at the dissolution
// boundary. Vertical bias makes it feel like gravity — content
// melts downward as new content crystallises in from above.
//
// Inputs:
//   position: pixel coordinates
//   color: source pixel color
//   size: view dimensions
//   progress: 0.0 (fully visible) → 1.0 (fully dissolved)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 tabMeltDissolve(float2 position, half4 color, float2 size, float progress) {
    // Early exit at extremes — skip noise when fully visible or fully dissolved
    if (progress < 0.001) return color;
    if (progress > 0.999) return half4(color.rgb, 0.0h);

    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // ── 2D value noise (hash-based, smoothstep interpolated) ──
    float2 cell = floor(uv * 14.0);
    float2 f = fract(uv * 14.0);
    f = f * f * (3.0 - 2.0 * f);

    float a = fract(sin(dot(cell,                 float2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(cell + float2(1, 0),  float2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(cell + float2(0, 1),  float2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(cell + float2(1, 1),  float2(127.1, 311.7))) * 43758.5453);

    float noise = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);

    // Vertical gravity: top pixels dissolve first → melt-down feel
    noise = noise * 0.7 + (1.0 - uv.y) * 0.3;

    // Expand threshold so full 0→1 range is covered
    float threshold = progress * 1.15;
    float edgeDist = noise - threshold;

    // Dissolved pixels → transparent
    float alpha = smoothstep(-0.02, 0.02, edgeDist);

    // Luminous green glow at the dissolution edge
    float edgeBand = smoothstep(0.0, 0.06, edgeDist)
                   * (1.0 - smoothstep(0.06, 0.14, edgeDist));
    half3 glow = half3(0.24h, 0.82h, 0.40h) * half(edgeBand * 0.55);

    half3 result = color.rgb + glow;
    return half4(saturate(result), color.a * half(alpha));
}


// ═══════════════════════════════════════════════════════════
// MARK: - Specular Sparkle (Gyroscope-Tracked)
// Ray-traced specular highlight that follows device tilt via
// CoreMotion gyroscope data. Used by the Living Menu system:
// when a user's gaze dwells on a card, a specular hotspot
// appears and tracks hand movement, making Liquid Glass
// surfaces "catch the light" like physical objects.
//
// Inputs:
//   position, color, size: standard stitchable params
//   lightX, lightY: normalised device roll/pitch (-1→+1)
//   intensity: bloom phase (0 = off, 0.25 = full bloom)
// ═══════════════════════════════════════════════════════════

[[ stitchable ]]
half4 specularSparkle(float2 position, half4 color, float2 size,
                       float lightX, float lightY, float intensity) {
    if (intensity < 0.001) return color;

    if (size.x < 1.0 || size.y < 1.0) return color;
    float2 uv = position / size;

    // Specular hotspot follows device tilt
    float2 lightPos = float2(0.5 + lightX * 0.35, 0.5 + lightY * 0.35);
    float dist = length(uv - lightPos);

    // Primary specular highlight — tight Gaussian
    float spec = exp(-dist * dist / 0.006) * intensity;

    // Micro-caustic sparkle pattern around the hotspot
    float c1 = sin(uv.x * 28.0 + lightX * 8.0) * cos(uv.y * 24.0 + lightY * 6.0);
    float sparkle = pow(clamp(c1 * 0.5 + 0.5, 0.0, 1.0), 14.0);
    sparkle *= exp(-dist * dist / 0.025) * intensity * 0.35;

    // Fresnel rim — light catches the glass edge
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float rim = (1.0 - smoothstep(0.0, 0.06, edgeDist)) * intensity * 0.2;

    half3 specColor = half3(1.0h, 0.98h, 0.94h); // warm white
    half3 result = color.rgb + specColor * half(spec + sparkle + rim);
    return half4(saturate(result), color.a);
}
