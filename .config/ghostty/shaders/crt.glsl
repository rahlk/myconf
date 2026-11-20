// Ghostty CRT source bundle. Edit all effects in this file.
// Run ../reload-shader (or ~/.config/ghostty/reload-shader) after editing.
// The build selects one CRT_PASS at compile time and keeps the original
// eight inexpensive GPU passes. Do not load this bundle directly as one pass.
#ifndef CRT_PASS
#define CRT_PASS 0
#endif


#if CRT_PASS == 0
// Pass 1: block-cursor-halo.glsl

// Smooth block cursor with a short green phosphor trail.
const float MOVE_DURATION = 0.12;
const float TRAIL_DURATION = 0.24;
const vec3 HALO_COLOR = vec3(0.32, 1.0, 0.48);

float blockDistance(vec2 pixel, vec4 cursor) {
    vec2 center = vec2(cursor.x + cursor.z * 0.5, cursor.y - cursor.w * 0.5);
    vec2 delta = abs(pixel - center) - cursor.zw * 0.5;
    return length(max(delta, vec2(0.0))) + min(max(delta.x, delta.y), 0.0);
}

float blockMask(vec2 pixel, vec4 cursor) {
    return 1.0 - smoothstep(-0.5, 0.5, blockDistance(pixel, cursor));
}

float blockHalo(vec2 pixel, vec4 cursor, float radius) {
    float outside = max(0.0, blockDistance(pixel, cursor));
    return exp(-outside * outside / (2.0 * radius * radius));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
    if (iFocus == 0 || iCursorVisible == 0 || iCurrentCursorStyle != 0 ||
        iCurrentCursor.z <= 0.0 || iCurrentCursor.w <= 0.0) return;

    float radius = max(1.5, iCurrentCursor.w * 0.12);
    float age = max(iTime - iTimeCursorChange, 0.0);
    vec2 movement = iCurrentCursor.xy - iPreviousCursor.xy;
    bool shortMove = abs(movement.y) <= iCurrentCursor.w * 1.25 &&
                     length(movement) > 0.5 &&
                     length(movement) <= iCurrentCursor.w * 8.0;
    vec4 head = iCurrentCursor;
    float glow = 0.0;

    if (shortMove && age < TRAIL_DURATION) {
        float progress = clamp(age / MOVE_DURATION, 0.0, 1.0);
        float eased = 1.0 - pow(1.0 - progress, 4.0);
        head.xy = mix(iPreviousCursor.xy, iCurrentCursor.xy, eased);

        if (age < MOVE_DURATION) {
            // Clear the native block while the animated block approaches it.
            float nativeMask = blockMask(fragCoord, iCurrentCursor);
            fragColor.rgb = mix(fragColor.rgb, iBackgroundColor * fragColor.a, nativeMask);
            float headMask = blockMask(fragCoord, head);
            fragColor = mix(fragColor, iCurrentCursorColor, headMask * 0.9);
        }

        float fade = pow(1.0 - age / TRAIL_DURATION, 1.5);
        // Soft additive light leaves underlying letters readable.
        for (int i = 0; i < 10; i++) {
            float along = float(i) / 9.0;
            vec4 tail = head;
            tail.xy = mix(iPreviousCursor.xy, head.xy, along);
            glow += blockHalo(fragCoord, tail, radius * 1.5)
                    * (0.025 + 0.055 * along) * fade;
        }
    }

    // A small halo also surrounds the resting block cursor.
    glow += blockHalo(fragCoord, head, radius) * 0.16;
    fragColor.rgb += HALO_COLOR * glow * (vec3(1.0) - fragColor.rgb);
    fragColor.rgb = clamp(fragColor.rgb, 0.0, 1.0);
}

#endif


#if CRT_PASS == 1
// Pass 2: analog-crt-tracking.glsl

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
    // Metal's Y axis points down: keep the Zellij tab row stationary at the top.
    float bodyWeight = smoothstep(96.0, max(192.0, iResolution.y * 0.10),
                                 fragCoord.y);

    // Burst gaps: 60-300 seconds. Each burst lasts half a second.
    float burstAge = eventAge(t, 180., 120., 17.3);
    float glitchAmount = 0.;
    if (burstAge >= 0. && burstAge < 0.5) {
        glitchAmount = sin(3.14159265359 * burstAge / 0.5);
    }
    vec2 st = vec2(0.);

    // Slower analog wobble instead of rapid per-frame noise.
    float y = uv.y * iResolution.y;
    float distortion = gnoise(vec3(0., y * .01, t * 8.)) * .1;
    distortion *= gnoise(vec3(0., y * .02, t * 4.)) * .025;
    // Slowly drift between random levels rather than flickering per frame.
    // The multiplier ranges from 0.75x to 1.75x the current jitter strength.
    float driftTime = t / 20.0;
    float driftSlot = floor(driftTime);
    float driftBlend = smoothstep(0.0, 1.0, fract(driftTime));
    float drift = mix(eventRandom(driftSlot, 313.7),
                      eventRandom(driftSlot + 1.0, 313.7), driftBlend);
    float driftMultiplier = mix(0.75, 1.75, drift);
    float jitterStrength = 0.016038 * driftMultiplier;
    distortion *= jitterStrength;
    // Limit only the continuous shimmer, before bursts, tracking, and screen drift.
    float maxJitter = 0.1188 / iResolution.x;
    distortion = clamp(distortion, -maxJitter, maxJitter);
    // Restore the original burst shake independently of the subtle shimmer.
    // Subtracting the baseline leaves 8*g*g + 0.3*g, which fades to zero.
    if (glitchAmount > 0.) {
        float burstNoise = gnoise(vec3(0., y * .01, t * 500.))
                         * gnoise(vec3(0., y * .02, t * 250.));
        float burstStrength = 8. * glitchAmount * glitchAmount + .3 * glitchAmount;
        distortion += burstNoise * burstStrength * .3375 * driftMultiplier;
    }

    // Original tracking distortion rolls down every 20-40 seconds.
    // Every sixth brightness sweep in the final overlay follows this same pass.
    float bandAge = eventAge(t, 30., 10., 83.7);
    float band = 0.;
    if (bandAge >= 0. && bandAge < 1.5) {
        float progress = bandAge / 1.5;
        float center = mix(-.05, 1.05, progress);
        float envelope = sin(3.14159265359 * progress);
        float stripe = (1. - smoothstep(.003, .024, abs(uv.y - center))) * envelope;
        stripe -= (1. - smoothstep(.003, .024, abs(uv.y - center + .04))) * envelope;
        band = stripe;
        distortion += band * .02;
    }
    distortion *= bodyWeight;

    // Coherent screen drift in physical pixels, independent of the faint
    // row wobble. Ease between random targets to avoid abrupt held jumps.
    float shakeTime = t * 7.0;
    float shakeSlot = floor(shakeTime);
    float shakeBlend = smoothstep(0.0, 1.0, fract(shakeTime));
    float screenDrift = mix(eventRandom(shakeSlot, 619.3),
                            eventRandom(shakeSlot + 1.0, 619.3), shakeBlend);
    distortion += (screenDrift * 2.0 - 1.0) * 1.25 / iResolution.x;

    st = uv + vec2(distortion, 0.);
    // Preserve RGB splitting during rare bursts and original tracking bands.
    vec2 edge = vec2(0.5) / iResolution.xy;
    float activity = clamp(max(glitchAmount, abs(band)), 0., 1.);
    vec2 split = vec2(5. / iResolution.x + abs(distortion) * .25, 0.) * activity * bodyWeight;
    vec3 col;
    col.r = textureLod(iChannel0, clamp(st + split, edge, vec2(1.0) - edge), 0.).r;
    col.g = textureLod(iChannel0, clamp(st, edge, vec2(1.0) - edge), 0.).g;
    col.b = textureLod(iChannel0, clamp(st - split, edge, vec2(1.0) - edge), 0.).b;
    fragColor = vec4(col, 1.);
}

#endif


#if CRT_PASS == 2
// Pass 3: crt-texture-v2.glsl

// source: https://gist.github.com/qwerasd205/c3da6c610c8ffe17d6d2d3cc7068f17f
// credits: https://github.com/qwerasd205
//==============================================================
//
//    [CRTS] PUBLIC DOMAIN CRT-STYLED SCALAR by Timothy Lottes
//
//    [+] Adapted with alterations for use in Ghostty by Qwerasd.
//    For more information on changes, see comment below license.
//
//==============================================================
//
//      LICENSE = UNLICENSE (aka PUBLIC DOMAIN)
//
//--------------------------------------------------------------
// This is free and unencumbered software released into the
// public domain.
//--------------------------------------------------------------
// Anyone is free to copy, modify, publish, use, compile, sell,
// or distribute this software, either in source code form or as
// a compiled binary, for any purpose, commercial or
// non-commercial, and by any means.
//--------------------------------------------------------------
// In jurisdictions that recognize copyright laws, the author or
// authors of this software dedicate any and all copyright
// interest in the software to the public domain. We make this
// dedication for the benefit of the public at large and to the
// detriment of our heirs and successors. We intend this
// dedication to be an overt act of relinquishment in perpetuity
// of all present and future rights to this software under
// copyright law.
//--------------------------------------------------------------
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
// KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
// PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
// AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//--------------------------------------------------------------
// For more information, please refer to
// <http://unlicense.org/>
//==============================================================

// This shader is a modified version of the excellent
// FixingPixelArtFast by Timothy Lottes on Shadertoy.
//
// The original shader can be found at:
// https://www.shadertoy.com/view/MtSfRK
//
// Modifications have been made to reduce the verbosity,
// and many of the comments have been removed / reworded.
// Additionally, the license has been moved to the top of
// the file, and can be read above. I (Qwerasd) choose to
// release the modified version under the same license.

// The appearance of this shader can be altered
// by adjusting the parameters defined below.

// "Scanlines" per real screen pixel.
// e.g. SCALE 0.5 means each scanline is 2 pixels.
// Recommended values:
//  o High DPI displays: 0.33333333
//  - Low DPI displays:  0.66666666
#define SCALE (1.0 / 6.0)

// "Tube" warp
#define CRTS_WARP 1

// Darkness of vignette in corners after warping
//  0.0 = completely black
//  1.0 = no vignetting
#define MIN_VIN 0.5

// Try different masks
// #define CRTS_MASK_GRILLE 1
// #define CRTS_MASK_GRILLE_LITE 1
// #define CRTS_MASK_NONE 1
#define CRTS_MASK_SHADOW 1

// Scanline thinness
//  0.50 = fused scanlines
//  0.70 = recommended default
//  1.00 = thinner scanlines (too thin)
#define INPUT_THIN 0.75

// Horizonal scan blur
//  -3.0 = pixely
//  -2.5 = default
//  -2.0 = smooth
//  -1.0 = too blurry
#define INPUT_BLUR -2.75

// Shadow mask effect, ranges from,
//  0.25 = large amount of mask (not recommended, too dark)
//  0.50 = recommended default
//  1.00 = no shadow mask
#define INPUT_MASK 0.65

float FromSrgb1(float c) {
  return (c <= 0.04045) ? c * (1.0 / 12.92) :
  pow(c * (1.0 / 1.055) + (0.055 / 1.055), 2.4);
}
vec3 FromSrgb(vec3 c) {
  return vec3(
    FromSrgb1(c.r), FromSrgb1(c.g), FromSrgb1(c.b));
}

vec3 CrtsFetch(vec2 uv) {
  return FromSrgb(texture(iChannel0, uv.xy).rgb);
}

#define CrtsRcpF1(x) (1.0/(x))
#define CrtsSatF1(x) clamp((x),0.0,1.0)

float CrtsMax3F1(float a, float b, float c) {
  return max(a, max(b, c));
}

vec2 CrtsTone(
  float thin,
  float mask) {
  #ifdef CRTS_MASK_NONE
  mask = 1.0;
  #endif

  #ifdef CRTS_MASK_GRILLE_LITE
  // Normal R mask is {1.0,mask,mask}
  // LITE   R mask is {mask,1.0,1.0}
  mask = 0.5 + mask * 0.5;
  #endif

  vec2 ret;
  float midOut = 0.18 / ((1.5 - thin) * (0.5 * mask + 0.5));
  float pMidIn = 0.18;
  ret.x = ((-pMidIn) + midOut) / ((1.0 - pMidIn) * midOut);
  ret.y = ((-pMidIn) * midOut + pMidIn) / (midOut * (-pMidIn) + midOut);

  return ret;
}

vec3 CrtsMask(vec2 pos, float dark) {
  #ifdef CRTS_MASK_GRILLE
  vec3 m = vec3(dark, dark, dark);
  float x = fract(pos.x * (1.0 / 3.0));
  if (x < (1.0 / 3.0)) m.r = 1.0;
  else if (x < (2.0 / 3.0)) m.g = 1.0;
  else m.b = 1.0;
  return m;
  #endif

  #ifdef CRTS_MASK_GRILLE_LITE
  vec3 m = vec3(1.0, 1.0, 1.0);
  float x = fract(pos.x * (1.0 / 3.0));
  if (x < (1.0 / 3.0)) m.r = dark;
  else if (x < (2.0 / 3.0)) m.g = dark;
  else m.b = dark;
  return m;
  #endif

  #ifdef CRTS_MASK_NONE
  return vec3(1.0, 1.0, 1.0);
  #endif

  #ifdef CRTS_MASK_SHADOW
  pos.x += pos.y * 3.0;
  vec3 m = vec3(dark, dark, dark);
  float x = fract(pos.x * (1.0 / 6.0));
  if (x < (1.0 / 3.0)) m.r = 1.0;
  else if (x < (2.0 / 3.0)) m.g = 1.0;
  else m.b = 1.0;
  return m;
  #endif
}

vec3 CrtsFilter(
  vec2 ipos,
  vec2 inputSizeDivOutputSize,
  vec2 halfInputSize,
  vec2 rcpInputSize,
  vec2 rcpOutputSize,
  vec2 twoDivOutputSize,
  float inputHeight,
  vec2 warp,
  float thin,
  float blur,
  float mask,
  vec2 tone
) {
  // Optional apply warp
  vec2 pos;
  #ifdef CRTS_WARP
  // Convert to {-1 to 1} range
  pos = ipos * twoDivOutputSize - vec2(1.0, 1.0);

  // Distort pushes image outside {-1 to 1} range
  pos *= vec2(
      1.0 + (pos.y * pos.y) * warp.x,
      1.0 + (pos.x * pos.x) * warp.y);

  // TODO: Vignette needs optimization
  float vin = 1.0 - (
      (1.0 - CrtsSatF1(pos.x * pos.x)) * (1.0 - CrtsSatF1(pos.y * pos.y)));
  vin = CrtsSatF1((-vin) * inputHeight + inputHeight);

  // Leave in {0 to inputSize}
  pos = pos * halfInputSize + halfInputSize;
  #else
  pos = ipos * inputSizeDivOutputSize;
  #endif

  // Snap to center of first scanline
  float y0 = floor(pos.y - 0.5) + 0.5;
  // Snap to center of one of four pixels
  float x0 = floor(pos.x - 1.5) + 0.5;

  // Inital UV position
  vec2 p = vec2(x0 * rcpInputSize.x, y0 * rcpInputSize.y);
  // Fetch 4 nearest texels from 2 nearest scanlines
  vec3 colA0 = CrtsFetch(p);
  p.x += rcpInputSize.x;
  vec3 colA1 = CrtsFetch(p);
  p.x += rcpInputSize.x;
  vec3 colA2 = CrtsFetch(p);
  p.x += rcpInputSize.x;
  vec3 colA3 = CrtsFetch(p);
  p.y += rcpInputSize.y;
  vec3 colB3 = CrtsFetch(p);
  p.x -= rcpInputSize.x;
  vec3 colB2 = CrtsFetch(p);
  p.x -= rcpInputSize.x;
  vec3 colB1 = CrtsFetch(p);
  p.x -= rcpInputSize.x;
  vec3 colB0 = CrtsFetch(p);

  // Vertical filter
  // Scanline intensity is using sine wave
  // Easy filter window and integral used later in exposure
  float off = pos.y - y0;
  float pi2 = 6.28318530717958;
  float hlf = 0.5;
  float scanA = cos(min(0.5, off * thin) * pi2) * hlf + hlf;
  float scanB = cos(min(0.5, (-off) * thin + thin) * pi2) * hlf + hlf;

  // Horizontal kernel is simple gaussian filter
  float off0 = pos.x - x0;
  float off1 = off0 - 1.0;
  float off2 = off0 - 2.0;
  float off3 = off0 - 3.0;
  float pix0 = exp2(blur * off0 * off0);
  float pix1 = exp2(blur * off1 * off1);
  float pix2 = exp2(blur * off2 * off2);
  float pix3 = exp2(blur * off3 * off3);
  float pixT = CrtsRcpF1(pix0 + pix1 + pix2 + pix3);

  #ifdef CRTS_WARP
  // Get rid of wrong pixels on edge
  pixT *= max(MIN_VIN, vin);
  #endif

  scanA *= pixT;
  scanB *= pixT;

  // Apply horizontal and vertical filters
  vec3 color =
    (colA0 * pix0 + colA1 * pix1 + colA2 * pix2 + colA3 * pix3) * scanA +
      (colB0 * pix0 + colB1 * pix1 + colB2 * pix2 + colB3 * pix3) * scanB;

  // Apply phosphor mask
  color *= CrtsMask(ipos, mask);

  // Tonal control, start by protecting from /0
  float peak = max(1.0 / (256.0 * 65536.0),
      CrtsMax3F1(color.r, color.g, color.b));
  // Compute the ratios of {R,G,B}
  vec3 ratio = color * CrtsRcpF1(peak);
  // Apply tonal curve to peak value
  peak = peak * CrtsRcpF1(peak * tone.x + tone.y);
  // Reconstruct color
  return ratio * peak;
}

float ToSrgb1(float c) {
  return (c < 0.0031308 ? c * 12.92 : 1.055 * pow(c, 0.41666) - 0.055);
}
vec3 ToSrgb(vec3 c) {
  return vec3(
    ToSrgb1(c.r), ToSrgb1(c.g), ToSrgb1(c.b));
}

// Flat CRT scan lines; phosphor bloom is applied in the final pass.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec4 color = texture(iChannel0, uv);
  // Blur strength increased by 20%, from 0.10 to 0.12.
  vec2 pixel = vec2(1.0 / iResolution.x, 0.0);
  vec3 softColor = (texture(iChannel0, clamp(uv - pixel, vec2(0.0), vec2(1.0))).rgb
                 + texture(iChannel0, clamp(uv + pixel, vec2(0.0), vec2(1.0))).rgb) * 0.5;
  color.rgb = mix(color.rgb, softColor, 0.12);
  // Phosphor attenuation increased by 50%, from 0.132 to 0.198.
  // Dark scanlines are applied after brightness in the final vignette pass.
  float scanline = 1.0;
  vec3 mask = CrtsMask(fragCoord, 0.802);
  float backgroundLuminance = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722));
  bool lightSurface = backgroundLuminance > 0.5;
  if (lightSurface) {
    // Fine white-paper CRT texture, independent of the dark-theme scanlines.
    float lightPitch = 3.0;
    // Bright segments have wider beams and narrower dark gaps.
    float brightness = clamp(dot(color.rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
    float beamWidth = lightPitch * mix(0.30, 0.375, smoothstep(0.10, 0.90, brightness));
    float beamDistance = (fract(fragCoord.y / lightPitch + 0.5) - 0.5) * lightPitch;
    float beam = exp(-0.5 * beamDistance * beamDistance / (beamWidth * beamWidth));
    scanline = 0.94 + 0.06 * beam;
    mask = vec3(0.99 + 0.01 * cos(6.28318530718 * fragCoord.x / lightPitch));
  }
  vec3 core = color.rgb * scanline * mask;
  fragColor = vec4(clamp(core, 0.0, 1.0), color.a);
}

#endif


#if CRT_PASS == 3
// Pass 4: phosphor-monochrome-paper.glsl

// Shared CRT monochrome brightness, inverted into ink for the paper profile.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);
    float backgroundPeak = max(iBackgroundColor.r, max(iBackgroundColor.g, iBackgroundColor.b));
    float backgroundLuminance = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722));
    if (backgroundLuminance > 0.5) {
        // Invert the dark-theme intensity rule: the darkest channel is ink.
        // Apply the same green phosphor contrast curve, then return grayscale.
        float paper = backgroundPeak;
        float ink = max(iForegroundColor.r, max(iForegroundColor.g, iForegroundColor.b));
        float darkest = min(fragColor.r, min(fragColor.g, fragColor.b));
        float intensity = clamp((paper - darkest) / max(paper - ink, 0.001), 0.0, 1.0);
        intensity = min(1.0, pow(intensity, 0.95) * 0.96);
        fragColor.rgb = vec3(mix(paper, ink, intensity));
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
            float aspect = iResolution.x / iResolution.y;
            pos *= vec2(1.0 + pos.y * pos.y / (50.0 * aspect),
                        1.0 + pos.x * pos.x / 50.0);
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

#endif


#if CRT_PASS == 4
// Pass 5: crt-finish-v2.glsl

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
        // Shimmer the scanline mask at 24 Hz, with a different phase per line.
        float scanlineIndex = floor(fragCoord.y / SCANLINE_PITCH);
        float scanY = fragCoord.y + 0.35 * sin(
            6.28318530718 * 24.0 * iTime + scanlineIndex * 1.7);
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

#endif


#if CRT_PASS == 5
// Pass 6: phosphor-bloom-stronger.glsl

// Tight phosphor glow around bright text, after the CRT scanlines.
#define BLOOM_RADIUS 3.0
#define BLOOM_STRENGTH 0.266


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

#endif


#if CRT_PASS == 6
// Pass 7: crt-curvature-subtle.glsl

// Gentle tube curvature, applied to the finished CRT image.
vec2 crtSurfaceUV(vec2 uv) {
    vec2 position = uv * 2.0 - 1.0;
    position *= vec2(1.0) + 0.006 * position.yx * position.yx;
    return position * 0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 surfaceUV = crtSurfaceUV(fragCoord / iResolution.xy);
    vec2 halfPixel = 0.5 / iResolution.xy;
    vec4 color = texture(iChannel0, clamp(surfaceUV, halfPixel, vec2(1.0) - halfPixel));
    // Feather the curved boundary into the theme background by one pixel.
    vec2 edgeDistance = min(surfaceUV, vec2(1.0) - surfaceUV) * iResolution.xy;
    float surfaceMask = smoothstep(-0.5, 0.5, min(edgeDistance.x, edgeDistance.y));
    fragColor = mix(vec4(iBackgroundColor, 1.0), color, surfaceMask);
}

#endif


#if CRT_PASS == 7
// Pass 8: crt-overlay-synced-curved-roll.glsl

// Rings and flicker use output pixels; brightness bands follow the curved raster.
vec2 crtSurfaceUV(vec2 uv) {
    vec2 position = uv * 2.0 - 1.0;
    position *= vec2(1.0) + 0.006 * position.yx * position.yx;
    return position * 0.5 + 0.5;
}

float ringPixelFilter(float phaseStep) {
    float halfStep = phaseStep * 0.5;
    return abs(halfStep) < 0.0001 ? 1.0 : sin(halfStep) / halfStep;
}

// Match the original tracking shader's event schedule exactly.
float eventRandom(float index, float seed) {
    return fract(sin(index * 127.1 + seed) * 43758.5453);
}

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

float scanBandAge(float t) {
    float trackingAge = eventAge(t, 30., 10., 83.7);
    if (trackingAge < 0.) return -1.;
    float trackingStart = t - trackingAge;
    float trackingSlot = floor(trackingStart / 30.);
    float nextTrackingStart = (trackingSlot + 1.) * 30. + 10.
                           + 10. * eventRandom(trackingSlot + 1., 83.7);
    // Six evenly spaced scans fit each original random tracking interval.
    float scanSpacing = (nextTrackingStart - trackingStart) / 6.;
    return mod(trackingAge, scanSpacing);
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

    // Each scan shares the original tracking band's 1.5-second motion.
    // Every sixth scan coincides with tracking distortion at the same Y position.
    float scanAge = scanBandAge(iTime);
    float rollingBand = 0.0;
    if (scanAge >= 0.0 && scanAge < 1.5) {
        float rollProgress = scanAge / 1.5;
        float rollCenter = mix(-.05, 1.05, rollProgress);
        float rollDistance = (crtSurfaceUV(uv).y - rollCenter) / (0.10 / 1.5);
        float rollFade = sin(3.14159265359 * rollProgress);
        rollingBand = exp(-0.5 * rollDistance * rollDistance) * rollFade;
    }
    float luminance = dot(fragColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    bool paper = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722)) > 0.5;
    if (paper) {
        // A 7.2% shaded sweep stays visible on paper while preserving dark ink.
        float backgroundWeight = smoothstep(0.45, 0.95, luminance);
        fragColor.rgb *= 1.0 - 0.072 * rollingBand * backgroundWeight;
    } else {
        // Dim the glass and background glow by up to 4.8%, preserving bright text.
        float peak = max(fragColor.r, max(fragColor.g, fragColor.b));
        float backgroundWeight = 1.0 - smoothstep(0.05, 0.35, peak);
        fragColor.rgb *= 1.0 - 0.048 * rollingBand * backgroundWeight;
    }

    // Subtle CRT brightness flutter: two rhythms keep the pulse uneven.
    // Limit dimming to 0.5% (0.25% average) and preserve alpha.
    float flicker = 0.9975
                  + (0.005 / 3.0) * sin(6.28318530718 * 17.0 * iTime)
                  + (0.005 / 6.0) * sin(6.28318530718 * 29.0 * iTime);
    fragColor.rgb *= flicker;
}

#endif
