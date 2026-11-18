// CRT raster motion, derived from the scheduling in glitch-steady-light-v2.glsl.
float eventRandom(float index, float seed) {
    return fract(sin(index * 127.1 + seed) * 43758.5453);
}

// One event per slot with a random offset. Consecutive gaps stay within
// period +/- spread, without an expensive per-frame scheduling loop.
float eventAge(float t, float period, float spread, float seed) {
    float slot = floor(t / period);
    float start = slot * period + (period - spread) * .5
                + spread * eventRandom(slot, seed);
    if (t >= start) return t - start;
    if (slot < 1.) return -1.;
    float previous = (slot - 1.) * period + (period - spread) * .5
                   + spread * eventRandom(slot - 1., seed);
    return t - previous;
}

// DOS CRT motion: irregular held raster jitter, measured in physical pixels.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;
    // Keep the top tab bar aligned with mouse coordinates.
    float bodyWeight = smoothstep(96.0, max(192.0, iResolution.y * 0.10), fragCoord.y);
    // Sample-and-hold raster instability: no sine wave or temporal interpolation.
    // Occasional repeated samples make the cadence irregular instead of clockwork.
    float tick = floor(t * 30.0);
    float sampleTick = tick - step(0.82, eventRandom(tick, 91.7));
    float horizontalJitter = eventRandom(sampleTick, 313.7) * 2.0 - 1.0;
    float scanline = floor(fragCoord.y / 6.0);
    float lineJitter = eventRandom(sampleTick + scanline * 173.0, 47.1) * 2.0 - 1.0;
    float offsetPixels = 0.32 * horizontalJitter + 0.16 * lineJitter;
    // Discrete eighth-pixel shifts avoid the previous continuously gliding edges.
    offsetPixels = clamp(floor(offsetPixels * 8.0 + 0.5) / 8.0, -0.5, 0.5);

    // A single soft tracking band occasionally passes through the raster.
    float bandAge = eventAge(t, 30.0, 10.0, 83.7);
    if (bandAge >= 0.0 && bandAge < 1.5) {
        float progress = bandAge / 1.5;
        float center = mix(-0.05, 1.05, progress);
        float band = 1.0 - smoothstep(0.004, 0.035, abs(uv.y - center));
        offsetPixels += 0.35 * band * sin(3.14159265359 * progress);
    }
    uv.x += offsetPixels * bodyWeight / iResolution.x;
    vec2 edge = vec2(0.5) / iResolution.xy;
    fragColor = textureLod(iChannel0, clamp(uv, edge, vec2(1.0) - edge), 0.0);
}
