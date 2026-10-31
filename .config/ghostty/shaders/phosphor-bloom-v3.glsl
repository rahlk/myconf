// Tight phosphor glow around bright text, after the CRT scanlines.
#define BLOOM_RADIUS 3.0
#define BLOOM_STRENGTH 0.20

float flickerRandom(float index, float seed) {
    return fract(sin(index * 127.1 + seed) * 43758.5453);
}

vec3 phosphorLight(vec2 uv) {
    vec2 halfPixel = 0.5 / iResolution.xy;
    vec3 color = texture(iChannel0, clamp(uv, halfPixel, vec2(1.0) - halfPixel)).rgb;
    vec3 light = max(color - iBackgroundColor, vec3(0.0));
    float brightness = max(light.r, max(light.g, light.b));
    return light * smoothstep(0.20, 0.65, brightness);
}

float bloomWeight(int offset) {
    return offset == 0 ? 6.0 : (abs(offset) == 1 ? 4.0 : 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);
    // Keep this waveform synchronized with the final CRT brightness flicker.
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
    float glowFlutter = flicker - 1.0;
    vec2 spread = vec2(BLOOM_RADIUS * 0.5 * clamp(1.0 + 2.0 * glowFlutter, 0.55, 1.45)) / iResolution.xy;
    vec3 bloom = vec3(0.0);
    // A normalized 5x5 Gaussian kernel spreads light without blurring the original text.
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            float weight = bloomWeight(x) * bloomWeight(y);
            bloom += phosphorLight(uv + vec2(float(x), float(y)) * spread) * weight;
        }
    }
    bloom /= 256.0;
    fragColor.rgb += BLOOM_STRENGTH * clamp(1.0 + 4.0 * glowFlutter, 0.15, 1.9) * bloom * (vec3(1.0) - clamp(fragColor.rgb, 0.0, 1.0));
}
