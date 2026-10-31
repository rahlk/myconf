// Flat CRT overlay preserves mouse alignment; rings and flicker use output pixels.
float ringPixelFilter(float phaseStep) {
    float halfStep = phaseStep * 0.5;
    return abs(halfStep) < 0.0001 ? 1.0 : sin(halfStep) / halfStep;
}


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);
    // Generate rings in output pixels, after scanlines and bloom.
    vec2 centered = fragCoord - iResolution.xy * 0.5;
    float radius = length(centered);
    float screenSize = min(iResolution.x, iResolution.y);
    float phase = radius * (6.28318530718 / 3.0);
    // Integrate the sinusoid across each pixel to suppress sampling artifacts.
    float filteredAmplitude = ringPixelFilter(dFdx(phase)) * ringPixelFilter(dFdy(phase));
    float ring = 0.5 + 0.5 * cos(phase) * filteredAmplitude;
    float backgroundPeak = max(iBackgroundColor.r, max(iBackgroundColor.g, iBackgroundColor.b));
    bool green = iForegroundColor.g > iForegroundColor.r * 1.25 &&
                 iForegroundColor.g > iForegroundColor.b * 1.25;
    bool red = iForegroundColor.r > iForegroundColor.g * 1.25;
    if ((green || red) && backgroundPeak < 0.12) {
        float radialFade = exp(-2.3 * pow(radius / (screenSize * 0.65), 2.0));
        float peak = max(fragColor.r, max(fragColor.g, fragColor.b));
        float backgroundWeight = 1.0 - smoothstep(0.025, 0.20, peak);
        vec3 ringColor = green ? vec3(0.015, 0.144, 0.033)
                              : vec3(0.144, 0.0678, 0.0288);
        fragColor.rgb += ringColor * ring * radialFade * backgroundWeight;
    }
}
