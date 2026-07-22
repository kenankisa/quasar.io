#include <flutter/runtime_effect.glsl>

// Reference-art black hole (Stage 4 "QUASAR.IO" look):
//  - tilted 3D accretion disk, turbulent orange/amber filaments
//  - front of the disk passes IN FRONT of the shadow, back passes behind
//  - lensed halo of the far disk arcing over/under the shadow (Gargantua)
//  - razor-thin white-hot photon ring on the shadow edge
//  - twin blue-white relativistic jets from both poles

uniform vec2 uSize;
uniform float uRs;
uniform float uShadowR;
uniform float uDiskR;
uniform float uSpin;
uniform float uIntensity;
uniform float uBoost;
uniform float uSwallowCharge;
uniform vec3 uHot0;
uniform vec3 uHot1;
uniform vec3 uHot2;
uniform vec3 uCool0;
uniform float uTime;
uniform float uLod;
uniform float uInfluxFlux;

out vec4 fragColor;

// Disk inclination — vertical squash of the disk plane (reference ≈ 1:3).
const float TILT = 0.34;

// Turbulent filament streaks flowing along the disk (log-spiral flow lines).
float filaments(float a, float rd, float t, float lod) {
    float lr = log(max(rd, 1.0));
    float f = 0.66
        + 0.22 * sin(a * 6.0 - lr * 5.2 + t * 1.4)
        + 0.12 * sin(a * 13.0 - lr * 9.5 - t * 2.1);
    if (lod >= 1.8) {
        f += 0.08 * sin(a * 25.0 - lr * 15.0 + t * 3.2);
    }
    return clamp(f, 0.2, 1.12);
}

// Temperature ramp: 0 = outer ember, 1 = inner white-hot (reference palette).
vec3 heatColor(float heat) {
    vec3 c = mix(uHot2 * 0.55, uHot2, smoothstep(0.0, 0.28, heat));
    c = mix(c, uHot1, smoothstep(0.2, 0.58, heat));
    c = mix(c, uHot0, smoothstep(0.5, 0.82, heat));
    c = mix(c, vec3(1.0, 0.98, 0.94), smoothstep(0.8, 1.0, heat));
    return c;
}

// Thin-disk emission in tilted disk space; also outputs normalized heat.
// Inner edge hugs the photon ring so the disk stays visible around the
// shadow (reference art), instead of hiding behind it.
float diskEmission(float rd, float a, float t, float lod, out float heat) {
    float inner = uShadowR * 1.0;
    float outer = max(uDiskR, inner * 1.45);
    float band = smoothstep(inner * 0.93, inner * 1.08, rd)
               * smoothstep(outer * 1.06, outer * 0.78, rd);
    heat = 0.0;
    if (band <= 0.002) return 0.0;

    // Emission peaks at the inner edge and decays outward (thin disk).
    float radial = exp(-(rd - inner) / max((outer - inner) * 1.2, 1.0));
    heat = clamp(radial * 1.15, 0.0, 1.0) * band;

    // Keep the outer disk glowing ember-orange instead of fading to black.
    heat = 0.22 + 0.78 * heat;

    float fil = filaments(a, rd, t, lod);
    // Relativistic Doppler beaming — approaching side brighter.
    float dop = 0.62 + 0.38 * cos(a);
    return band * (0.85 + radial * 1.2) * fil * dop;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 p = fragCoord - uSize * 0.5;
    float r = length(p);
    float extent = max(uSize.x, uSize.y) * 0.5;
    if (r > extent) {
        fragColor = vec4(0.0);
        return;
    }

    float spin = uSpin * 0.12;
    float intensity = clamp(uIntensity, 0.55, 2.2);
    float boost = clamp(uBoost, 1.0, 1.45);
    float hunt = clamp(uSwallowCharge, 0.0, 1.0);
    float lod = clamp(uLod, 0.0, 2.0);
    float influx = clamp(uInfluxFlux, 0.0, 1.0);
    float t = uTime;

    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // ---- Primary tilted disk (computed once, split front/back) ----
    vec2 d = vec2(p.x, p.y / TILT);
    float rd = length(d);
    // Orbital flow: pattern angle advances with spin + time.
    float ad = atan(d.y, d.x) + spin * 1.6 + t * 0.5;

    float heat;
    float e = diskEmission(rd, ad, t, lod, heat);
    float diskGain = intensity * boost * (1.0 + hunt * 0.45 + influx * 0.35);
    vec3 diskCol = heatColor(heat) * e * 1.9 * diskGain;

    // Full-strength disk everywhere; the shadow pass below punches out the
    // part behind the hole and the front band is re-added on top afterwards.
    col += diskCol;
    alpha = max(alpha, min(e * 1.35, 1.0));

    // ---- Lensed halo — far-side disk image bent over/under the shadow ----
    float haloBand = smoothstep(uShadowR * 0.99, uShadowR * 1.08, r)
                   * smoothstep(uShadowR * 1.55, uShadowR * 1.12, r);
    if (haloBand > 0.002) {
        float ny = p.y / max(r, 1.0);
        // Far side (top) dominates the lensed image, faint echo below.
        float topW = 0.22 + 0.78 * smoothstep(0.35, -0.85, ny);
        float haloHeat = smoothstep(uShadowR * 1.55, uShadowR * 1.02, r);
        float haloFil = filaments(atan(p.y, p.x) + spin * 1.2, r * 2.4, t, lod);
        vec3 haloCol = heatColor(haloHeat * 0.92);
        float haloE = haloBand * topW * haloFil * (0.4 + haloHeat * 0.65);
        col += haloCol * haloE * intensity * 0.9;
        alpha = max(alpha, haloE * 0.8);
    }

    // ---- Gravitational shadow — pure black void ----
    float shadowMask = smoothstep(uShadowR * 1.01, uShadowR * 0.84, r);
    col *= (1.0 - shadowMask);
    alpha = max(alpha, smoothstep(uShadowR * 1.02, uShadowR * 0.6, r));

    // ---- Photon ring — thin white-hot ring hugging the shadow ----
    float ringDist = abs(r - uShadowR);
    float ringCoreW = max(uRs * 0.05, 0.9);
    float ringHaloW = max(uRs * 0.14, 1.9);
    float ringCore = exp(-ringDist * ringDist / (ringCoreW * ringCoreW));
    float ringHalo = exp(-ringDist * ringDist / (ringHaloW * ringHaloW));
    float ringAsym = 0.55 + 0.45 * pow(max(0.0, cos(atan(p.y, p.x) + spin * 0.8)), 2.0);
    float ringBright = (ringCore * 1.5 + ringHalo * 0.4) * ringAsym
                     * (1.0 + hunt * 0.6 + influx * 0.25);
    vec3 ringCol = mix(uHot0, vec3(1.0, 0.97, 0.9), 0.72);
    col += ringCol * ringBright * intensity * 1.55;
    alpha = max(alpha, min(ringBright, 1.0) * 0.95);

    // ---- Front disk band — near side of the annulus passes IN FRONT of the
    //      shadow's lower half (matter between the camera and the hole) ----
    float frontW = smoothstep(0.0, uRs * 0.3, p.y) * smoothstep(uShadowR * 1.05, uShadowR * 0.9, r);
    col += diskCol * frontW;
    alpha = max(alpha, min(e * 1.35, 1.0) * frontW);

    // ---- Relativistic polar jets — blue-white beams from both poles ----
    // The beam emerges at the pole (top/bottom of the photon ring) and is
    // fully hidden by the event horizon, matching the reference art.
    float jy = abs(p.y);
    float jx = abs(p.x);
    float jetStart = uShadowR * 0.86;
    if (jy > jetStart * 0.9) {
        float coreW = max(uRs * 0.13, 1.2) * (1.0 + (jy / extent) * 0.9);
        float jetCore = exp(-(jx * jx) / (coreW * coreW));
        float glowW = coreW * 2.6;
        float jetGlow = exp(-(jx * jx) / (glowW * glowW));
        float lenFade = smoothstep(extent * 1.02, jetStart, jy);
        float baseMask = smoothstep(jetStart * 0.92, jetStart * 1.18, jy);
        // Plasma knots streaming outward along the beam.
        float knots = 0.8 + 0.2 * sin(jy / max(uRs * 0.55, 1.0) - t * 7.5);
        float jetStrength = (0.42 + hunt * 0.55 + influx * 0.3 + (boost - 1.0) * 0.7)
                          * intensity;
        vec3 jetTint = mix(vec3(0.5, 0.78, 1.0), vec3(0.72, 0.55, 1.0),
                           smoothstep(uShadowR, extent, jy) * 0.6);
        vec3 jetCol = vec3(1.0, 1.0, 1.0) * jetCore * 0.95 + jetTint * jetGlow * 0.42;
        col += jetCol * lenFade * baseMask * knots * jetStrength;
        alpha = max(alpha,
            min((jetCore + jetGlow * 0.45) * lenFade * baseMask * jetStrength, 1.0) * 0.9);

        // Polar flash — bright spot where the beam punches through the ring.
        float poleDist = length(vec2(jx, jy - uShadowR));
        float pole = exp(-poleDist * poleDist / max(uRs * 0.4 * uRs * 0.4, 1.0));
        col += vec3(0.85, 0.92, 1.0) * pole * jetStrength * 0.8;
        alpha = max(alpha, pole * 0.6);
    }

    // ---- Bloom on bright emission ----
    if (lod >= 0.5) {
        float lum = dot(col, vec3(0.299, 0.587, 0.114));
        col += col * smoothstep(0.2, 0.95, lum) * (0.26 + 0.18 * (lod / 2.0));
    }

    // ---- Swallow charge — coronal rim pulse (hunt / feeding flare) ----
    if (hunt > 0.05) {
        float pulse = 0.52 + 0.48 * sin(t * 6.2 + hunt * 3.1);
        float rimDist = abs(r - uShadowR * 0.985);
        float rimW = max(uRs * 0.08, 1.1);
        float rimGlow = exp(-rimDist * rimDist / (rimW * rimW)) * hunt * pulse;
        col += mix(uHot0, vec3(1.0, 0.9, 0.66), 0.65) * rimGlow * intensity * 1.1;
        alpha = max(alpha, rimGlow * 0.7);
    }

    // ---- Soft edge falloff — glow fades out before the quad's circular
    //      cutoff so no hard "container circle" appears on big holes ----
    float edgeFade = 1.0 - smoothstep(extent * 0.86, extent * 0.995, r);
    col *= edgeFade;
    alpha *= edgeFade;

    alpha = clamp(alpha, 0.0, 1.0);
    fragColor = vec4(col, alpha);
}
