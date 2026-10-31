// Scanlines and vignette for CRT themes; rings are drawn after curvature.
#define VIGNETTE_STRENGTH 0.10
#define WHITE_TEXT_GAIN 2.0
#define SCANLINE_PITCH 6.0

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
    vec2 position = fragCoord / iResolution.xy * 2.0 - 1.0;
    float backgroundLuminance = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722));
    bool whiteOnBlue =
        iBackgroundColor.b > max(iBackgroundColor.r, iBackgroundColor.g) * 1.25 &&
        backgroundLuminance < 0.5 &&
        min(iForegroundColor.r, min(iForegroundColor.g, iForegroundColor.b)) > 0.7;
    // Select white letter cores before scanlines and vignette dim them.
    float whiteCore = smoothstep(0.67, 0.70,
        min(fragColor.r, min(fragColor.g, fragColor.b)));
    if (backgroundLuminance < 0.5) {
        float scanY = fragCoord.y;
        // Brighter phosphor widens the beam within each six-pixel scanline.
        float brightness = clamp(dot(fragColor.rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
        float beamWidth = SCANLINE_PITCH * mix(0.30, 0.375, smoothstep(0.10, 0.90, brightness));
        float beamDistance = (fract(scanY / SCANLINE_PITCH + 0.5) - 0.5) * SCANLINE_PITCH;
        float beam = exp(-0.5 * beamDistance * beamDistance / (beamWidth * beamWidth));
        fragColor.rgb *= 0.72 + 0.28 * beam;
    }
    float distanceFromCenter = dot(position, position) * 0.5;
    float vignetteStrength = backgroundLuminance > 0.5 ? 0.035 : VIGNETTE_STRENGTH;
    fragColor.rgb *= 1.0 - vignetteStrength * smoothstep(0.12, 1.0, distanceFromCenter);
    if (whiteOnBlue) {
        // Double white text after CRT attenuation, capped at display white.
        vec3 color = clamp(fragColor.rgb, 0.0, 1.0);
        vec3 brightWhite = min(vec3(1.0), color * WHITE_TEXT_GAIN);
        fragColor.rgb = mix(color, brightWhite, whiteCore);
    }
}
