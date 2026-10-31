// Flat CRT overlay preserves mouse alignment; rings and flicker use output pixels.
float ringPixelFilter(float phaseStep) {
    float halfStep = phaseStep * 0.5;
    return abs(halfStep) < 0.0001 ? 1.0 : sin(halfStep) / halfStep;
}

float flickerRandom(float index, float seed) {
    return fract(sin(index * 127.1 + seed) * 43758.5453);
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
    // Rapid tube-like flutter with random intensity, rather than isolated events.
    // Keep the frequencies below typical refresh rates to avoid locking at 60 Hz.
    float noiseTime = iTime * 54.0;
    float noiseSlot = floor(noiseTime);
    float noise = mix(flickerRandom(noiseSlot, 313.7),
                      flickerRandom(noiseSlot + 1.0, 313.7),
                      smoothstep(0.0, 1.0, fract(noiseTime))) * 2.0 - 1.0;
    float strengthTime = iTime * 3.0;
    float strengthSlot = floor(strengthTime);
    float strength = mix(flickerRandom(strengthSlot, 47.1),
                         flickerRandom(strengthSlot + 1.0, 47.1),
                         smoothstep(0.0, 1.0, fract(strengthTime)));
    float flutter = 0.024 * sin(6.28318530718 * 26.3 * iTime + noise * 0.5)
                  + 0.020 * noise;
    float flicker = 1.0 + flutter * mix(0.8, 1.0, strength);
    // Keep white paper stable while retaining a faint light-mode flutter.
    float backgroundLuminance = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722));
    fragColor.rgb *= backgroundLuminance > 0.5 ? mix(1.0, flicker, 0.15) : flicker;
}
