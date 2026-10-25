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

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;

    // Burst gaps: 60-300 seconds. Each burst lasts half a second.
    float burstAge = eventAge(t, 180., 120., 17.3);
    float glitchAmount = 0.;
    if (burstAge >= 0. && burstAge < 0.5) {
        glitchAmount = sin(3.14159265359 * burstAge / 0.5);
    }
    vec2 st = vec2(0.);

    // analog distortion
    float y = uv.y * iResolution.y;
    float distortion = gnoise(vec3(0., y * .01, t * 500.)) * (glitchAmount * 4. + .1);
    distortion *= gnoise(vec3(0., y * .02, t * 250.)) * (glitchAmount * 2. + .025);
    // Slowly drift between random levels rather than flickering per frame.
    // The multiplier ranges from 0.75x to 1.75x the current jitter strength.
    float driftTime = t / 5.0;
    float driftSlot = floor(driftTime);
    float driftBlend = smoothstep(0.0, 1.0, fract(driftTime));
    float drift = mix(eventRandom(driftSlot, 313.7),
                      eventRandom(driftSlot + 1.0, 313.7), driftBlend);
    float jitterStrength = 0.3375 * mix(0.75, 1.75, drift);
    distortion *= jitterStrength;

    // Independent band gaps: 20-40 seconds, moving bottom to top.
    float bandAge = eventAge(t, 30., 10., 83.7);
    float band = 0.;
    if (bandAge >= 0. && bandAge < 2.0) {
        // Select one or three bands once per event, not once per frame.
        float eventSlot = floor((t - bandAge + 0.001) / 30.);
        int bandCount = eventRandom(eventSlot, 151.9) < 0.5 ? 1 : 3;
        // Each pass lasts 1.5 seconds, with starts 0.25s apart.
        // The leading pass remains aligned with the CRT bloom reset.
        for (int i = 0; i < 3; i++) {
            if (i >= bandCount) break;
            float age = bandAge - float(i) * 0.25;
            if (age >= 0. && age < 1.5) {
                float progress = age / 1.5;
                float center = mix(-.05, 1.05, progress);
                float envelope = sin(3.14159265359 * progress);
                float stripe = (1. - smoothstep(.003, .016, abs(uv.y - center))) * envelope;
                stripe -= (1. - smoothstep(.003, .016, abs(uv.y - center + .04))) * envelope;
                band += stripe;
            }
        }
        distortion += band * .02;
    }
    st = uv + vec2(distortion, 0.);
    // Restore RGB splitting during bursts and passing bands, without noise.
    vec2 edge = vec2(0.5) / iResolution.xy;
    float activity = max(glitchAmount, abs(band));
    vec2 split = vec2(5. / iResolution.x + abs(distortion) * .25, 0.) * activity;
    vec3 col;
    col.r = textureLod(iChannel0, clamp(st + split, edge, vec2(1.0) - edge), 0.).r;
    col.g = textureLod(iChannel0, clamp(st, edge, vec2(1.0) - edge), 0.).g;
    col.b = textureLod(iChannel0, clamp(st - split, edge, vec2(1.0) - edge), 0.).b;
    fragColor = vec4(col, 1.);
}
