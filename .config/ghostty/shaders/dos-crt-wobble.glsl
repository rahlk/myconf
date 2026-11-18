// modified version of https://www.shadertoy.com/view/wld3WN
// amount of seconds for which the glitch loop occurs
#define DURATION 10.
// percentage of the duration for which the glitch is triggered
#define AMT .1

#define SS(a, b, x) (smoothstep(a, b, x) * smoothstep(b, a, x))

#define UI0 1597334673U
#define UI1 3812015801U
#define UI2 uvec2(UI0, UI1)
#define UI3 uvec3(UI0, UI1, 2798796415U)
#define UIF (1. / float(0xffffffffU))

// Hash by David_Hoskins
vec3 hash33(vec3 p)
{
    uvec3 q = uvec3(ivec3(p)) * UI3;
    q = (q.x ^ q.y ^ q.z)*UI3;
    return -1. + 2. * vec3(q) * UIF;
}

// Gradient noise by iq
float gnoise(vec3 x)
{
    // grid
    vec3 p = floor(x);
    vec3 w = fract(x);

    // quintic interpolant
    vec3 u = w * w * w * (w * (w * 6. - 15.) + 10.);

    // gradients
    vec3 ga = hash33(p + vec3(0., 0., 0.));
    vec3 gb = hash33(p + vec3(1., 0., 0.));
    vec3 gc = hash33(p + vec3(0., 1., 0.));
    vec3 gd = hash33(p + vec3(1., 1., 0.));
    vec3 ge = hash33(p + vec3(0., 0., 1.));
    vec3 gf = hash33(p + vec3(1., 0., 1.));
    vec3 gg = hash33(p + vec3(0., 1., 1.));
    vec3 gh = hash33(p + vec3(1., 1., 1.));

    // projections
    float va = dot(ga, w - vec3(0., 0., 0.));
    float vb = dot(gb, w - vec3(1., 0., 0.));
    float vc = dot(gc, w - vec3(0., 1., 0.));
    float vd = dot(gd, w - vec3(1., 1., 0.));
    float ve = dot(ge, w - vec3(0., 0., 1.));
    float vf = dot(gf, w - vec3(1., 0., 1.));
    float vg = dot(gg, w - vec3(0., 1., 1.));
    float vh = dot(gh, w - vec3(1., 1., 1.));

    // interpolation
    float gNoise = va + u.x * (vb - va) +
                u.y * (vc - va) +
                u.z * (ve - va) +
                u.x * u.y * (va - vb - vc + vd) +
                u.y * u.z * (va - vc - ve + vg) +
                u.z * u.x * (va - vb - ve + vf) +
                u.x * u.y * u.z * (-va + vb + vc - vd + ve - vf - vg + vh);

    return 2. * gNoise;
}

// gradient noise in range [0, 1]
float gnoise01(vec3 x)
{
    return .5 + .5 * gnoise(x);
}

// warp uvs for the crt effect
vec2 crt(vec2 uv)
{
    float tht  = atan(uv.y, uv.x);
    float r = length(uv);
    // curve without distorting the center
    r /= (1. - .1 * r * r);
    uv.x = r * cos(tht);
    uv.y = r * sin(tht);
    return .5 * (uv + 1.);
}


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

// DOS CRT motion: a faint horizontal raster wobble, measured in physical pixels.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;
    // Keep the top tab bar aligned with mouse coordinates.
    float bodyWeight = smoothstep(96.0, max(192.0, iResolution.y * 0.10), fragCoord.y);
    float driftTime = t / 20.0;
    float driftSlot = floor(driftTime);
    float drift = mix(eventRandom(driftSlot, 313.7),
                      eventRandom(driftSlot + 1.0, 313.7),
                      smoothstep(0.0, 1.0, fract(driftTime)));
    float rasterNoise = gnoise(vec3(0.0, fragCoord.y * 0.012, t * 5.3));
    float slowWobble = sin(t * 2.1 + uv.y * 5.0);
    float offsetPixels = (0.40 * rasterNoise + 0.15 * slowWobble)
                       * mix(0.75, 1.15, drift);
    offsetPixels = clamp(offsetPixels, -0.55, 0.55);

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
