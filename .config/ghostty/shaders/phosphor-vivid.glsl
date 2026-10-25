// Shared CRT brightness for green/red profiles; grayscale for the light theme.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
    float backgroundPeak = max(iBackgroundColor.r, max(iBackgroundColor.g, iBackgroundColor.b));
    float backgroundLuminance = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722));
    if (backgroundLuminance > 0.5) {
        float gray = dot(fragColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        fragColor.rgb = vec3(gray) * iBackgroundColor / backgroundPeak;
        return;
    }
    bool green = iForegroundColor.g > iForegroundColor.r * 1.25 &&
                 iForegroundColor.g > iForegroundColor.b * 1.25;
    bool red = iForegroundColor.r > iForegroundColor.g * 1.25;
    if (!green && !red) return;

    // Warm orange-red, preserving the shared green/red brightness curve.
    vec3 foreground = green ? iForegroundColor : vec3(255.0, 120.0, 51.0) / 255.0;
    vec3 background = green ? iBackgroundColor : vec3(4.0, 0.0, 0.0) / 255.0;
    float intensity = max(fragColor.r, max(fragColor.g, fragColor.b));
    // Read the pale bold color before all text is tinted back to green.
    float paleText = min(fragColor.r, min(fragColor.g, fragColor.b)) / max(intensity, 0.001);
    float boldEmphasis = smoothstep(0.56, 0.64, paleText);
    if (intensity <= backgroundPeak + 0.002) {
        if (red) {
            vec2 pos = fragCoord / iResolution.xy * 2.0 - 1.0;
            // Curved background bounds disabled.
            // float aspect = iResolution.x / iResolution.y;
            // pos *= vec2(1.0 + pos.y * pos.y / (50.0 * aspect),
            //             1.0 + pos.x * pos.x / 50.0);
            if (all(lessThanEqual(abs(pos), vec2(1.0)))) {
                float shade = backgroundPeak > 0.001 ? clamp(intensity / backgroundPeak, 0.0, 1.0) : 1.0;
                fragColor.rgb = background * shade;
            }
        }
        return;
    }
    intensity = clamp((intensity - backgroundPeak) / max(1.0 - backgroundPeak, 0.001), 0.0, 1.0);
    float peak = max(foreground.r, max(foreground.g, foreground.b));
    vec3 phosphor = foreground / max(peak, 0.001);
    // Keep faint green edges dark so bold bitmap glyphs retain their gaps.
    // Bright cores keep their phosphor glow without flattening the highlights.
    float exponent = green ? 0.95 : 0.60;
    // Lift normal green text while keeping brighter emphasis for bold.
    float gain = green ? mix(0.96, 1.12, boldEmphasis) : 1.15;
    intensity = min(1.0, pow(intensity, exponent) * gain);
    fragColor.rgb = background + (vec3(1.0) - background) * phosphor * intensity;
}
