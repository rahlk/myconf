// Tight phosphor glow around bright text, after the CRT scanlines.
#define BLOOM_RADIUS 3.0
#define BLOOM_STRENGTH 0.20


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
    vec2 spread = vec2(BLOOM_RADIUS * 0.5) / iResolution.xy;
    vec3 bloom = vec3(0.0);
    // A normalized 5x5 Gaussian kernel spreads light without blurring the original text.
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            float weight = bloomWeight(x) * bloomWeight(y);
            bloom += phosphorLight(uv + vec2(float(x), float(y)) * spread) * weight;
        }
    }
    bloom /= 256.0;
    fragColor.rgb += BLOOM_STRENGTH * bloom * (vec3(1.0) - clamp(fragColor.rgb, 0.0, 1.0));
}
