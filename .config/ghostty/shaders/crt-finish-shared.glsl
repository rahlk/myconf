// Background glow, scanlines, and vignette for green/red/blue CRT themes.
#define VIGNETTE_STRENGTH 0.10
#define BLUE_VIGNETTE_STRENGTH 0.165

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
    vec2 position = fragCoord / iResolution.xy * 2.0 - 1.0;
    float backgroundPeak = max(iBackgroundColor.r, max(iBackgroundColor.g, iBackgroundColor.b));
    float backgroundLuminance = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722));
    bool green = iForegroundColor.g > iForegroundColor.r * 1.25 &&
                 iForegroundColor.g > iForegroundColor.b * 1.25;
    bool red = iForegroundColor.r > iForegroundColor.g * 1.25;
    if ((green || red) && backgroundPeak < 0.12) {
        // Curvature disabled; retain the original curved glow bounds.
        // float aspect = iResolution.x / iResolution.y;
        // vec2 tubePosition = position * vec2(1.0 + position.y * position.y / (50.0 * aspect),
        //                                    1.0 + position.x * position.x / 50.0);
        vec2 tubePosition = position;
        if (all(lessThanEqual(abs(tubePosition), vec2(1.0)))) {
            float glowRadius = green ? 1.3 : 1.0;
            float radialGlow = exp(-2.3 * dot(position, position) / (glowRadius * glowRadius));
            float peak = max(fragColor.r, max(fragColor.g, fragColor.b));
            float backgroundWeight = 1.0 - smoothstep(0.025, 0.20, peak);
            vec3 centerGlow = vec3(6.76, 27.04, 12.168) / 255.0;
            if (red) centerGlow = vec3(16.0, 7.53, 3.2) / 255.0;
            fragColor.rgb += centerGlow * radialGlow * backgroundWeight;
        }
    }
    bool whiteOnBlue =
        iBackgroundColor.b > max(iBackgroundColor.r, iBackgroundColor.g) * 1.25 &&
        backgroundLuminance < 0.5 &&
        min(iForegroundColor.r, min(iForegroundColor.g, iForegroundColor.b)) > 0.7;
    // Select white letter cores before scanlines and vignette dim them.
    float whiteCore = smoothstep(0.45, 0.75,
        min(fragColor.r, min(fragColor.g, fragColor.b)));
    if (whiteOnBlue) {
        // Curvature disabled; retain the original curved glow bounds.
        // float aspect = iResolution.x / iResolution.y;
        // vec2 tubePosition = position * vec2(1.0 + position.y * position.y / (50.0 * aspect),
        //                                    1.0 + position.x * position.x / 50.0);
        vec2 tubePosition = position;
        if (all(lessThanEqual(abs(tubePosition), vec2(1.0)))) {
            float glowRadius = 1.3;
            float radialGlow = exp(-2.3 * dot(position, position) / (glowRadius * glowRadius));
            // Red/green contrast keeps the blue shadow mask from suppressing glow.
            vec3 difference = abs(fragColor.rgb - iBackgroundColor);
            float contrast = max(difference.r, difference.g);
            float backgroundWeight = 1.0 - smoothstep(0.025, 0.20, contrast);
            vec3 centerGlow = iBackgroundColor / max(backgroundPeak, 0.001) * (27.04 / 255.0);
            fragColor.rgb += centerGlow * radialGlow * backgroundWeight;
        }
    }
    if (backgroundLuminance < 0.5) {
        // Curved scanlines disabled; retain the original mapping.
        // float curvedY = position.y * (1.0 + position.x * position.x / 50.0);
        // float scanY = (curvedY * 0.5 + 0.5) * iResolution.y;
        float scanY = fragCoord.y;
        fragColor.rgb *= 0.86 + 0.14 * cos(6.28318530718 * scanY / 4.0);
    }
    float distanceFromCenter = dot(position, position) * 0.5;
    float vignetteStrength = whiteOnBlue ? BLUE_VIGNETTE_STRENGTH : VIGNETTE_STRENGTH;
    fragColor.rgb *= 1.0 - vignetteStrength * smoothstep(0.12, 1.0, distanceFromCenter);
    if (whiteOnBlue) {
        // Lift white highlights without clipping away the CRT modulation.
        vec3 color = clamp(fragColor.rgb, 0.0, 1.0);
        vec3 brightWhite = vec3(1.0) - pow(vec3(1.0) - color, vec3(4.0));
        fragColor.rgb = mix(color, brightWhite, whiteCore);
    }
}
