// Fractal Voyager - WGSL compute-shader variant
//
// A compute-shader form of the per-pixel kernel (one invocation per pixel,
// writing to a storage texture). It is kept as a standalone reference: the
// demo in web/index.html renders with the fragment shader embedded in that
// page, and this file is not produced by the public mindc release. It uses
// escape radius 2 and is validated in CI with naga.
//
// Copyright (c) 2026 STARGA Inc. - MIT License

struct ViewUniforms {
    center: vec2<f32>,
    zoom: f32,
    time: f32,
    max_iter: f32,
    width: f32,
    height: f32,
    fractal_type: i32,
    color_scheme: i32,
    audio_intensity: f32,
    julia_re: f32,
    julia_im: f32,
}

@group(0) @binding(0) var<uniform> view: ViewUniforms;
@group(0) @binding(1) var output_texture: texture_storage_2d<rgba8unorm, write>;

fn hsv2rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let x = c * (1.0 - abs(fract(h * 6.0 / 2.0) * 2.0 - 1.0));
    let m = v - c;
    var rgb: vec3<f32>;
    let hi = i32(floor(h * 6.0)) % 6;
    switch(hi) {
        case 0: { rgb = vec3<f32>(c, x, 0.0); }
        case 1: { rgb = vec3<f32>(x, c, 0.0); }
        case 2: { rgb = vec3<f32>(0.0, c, x); }
        case 3: { rgb = vec3<f32>(0.0, x, c); }
        case 4: { rgb = vec3<f32>(x, 0.0, c); }
        default: { rgb = vec3<f32>(c, 0.0, x); }
    }
    return rgb + m;
}

fn mandelbrot(z: vec2<f32>, c: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(z.x * z.x - z.y * z.y + c.x, 2.0 * z.x * z.y + c.y);
}

fn julia(z: vec2<f32>, jc: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(z.x * z.x - z.y * z.y + jc.x, 2.0 * z.x * z.y + jc.y);
}

fn burning_ship(z: vec2<f32>, c: vec2<f32>) -> vec2<f32> {
    let az = abs(z);
    return vec2<f32>(az.x * az.x - az.y * az.y + c.x, 2.0 * az.x * az.y + c.y);
}

fn tricorn(z: vec2<f32>, c: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(z.x * z.x - z.y * z.y + c.x, -2.0 * z.x * z.y + c.y);
}

fn get_color(scheme: i32, t: f32, iter: f32, time: f32, audio: f32) -> vec3<f32> {
    switch(scheme) {
        case 0: { // Electric
            let h = fract(t * 5.0 + time * 0.1 + audio * 2.0);
            return hsv2rgb(h, 0.8 + audio * 0.2, 0.9);
        }
        case 1: { // Fire
            let r = min(1.0, t * 3.0);
            let g = max(0.0, min(1.0, (t - 0.33) * 3.0)) * 0.6;
            let b = max(0.0, (t - 0.66) * 3.0) * 0.2;
            return vec3<f32>(r, g, b) * (1.0 + audio);
        }
        case 2: { // Ocean
            return vec3<f32>(t * 0.3, t * 0.6 + audio * 0.3, 0.4 + t * 0.6);
        }
        case 3: { // Neon
            let p = t * 12.566 + time * 0.1 + audio * 2.0;
            return vec3<f32>(
                0.5 + 0.5 * sin(p),
                0.5 + 0.5 * sin(p + 2.094),
                0.5 + 0.5 * sin(p + 4.188)
            ) * (1.0 + audio * 0.5);
        }
        case 4: { // Grayscale
            let v = sqrt(t);
            return vec3<f32>(v, v, v);
        }
        case 5: { // Psychedelic
            let h = fract(t * 10.0 + time * 0.1 + audio * 2.0);
            let s = 0.7 + 0.3 * sin(t * 20.0 + audio * 10.0);
            return hsv2rgb(h, s, 1.0);
        }
        case 6: { // Plasma
            let to = time * 0.1 + audio * 2.0;
            let x = sin(t * 6.283 + to) * 0.5 + 0.5;
            let y = cos(t * 9.425 + to * 0.7) * 0.5 + 0.5;
            return vec3<f32>(x, y * 0.5 + 0.5 * x, 1.0 - x * y) * (1.0 + audio * 0.3);
        }
        default: { // Galaxy
            let h = fract(t * 2.0 + 0.7);
            let s = 0.6 + 0.4 * sin(t * 10.0);
            var c = hsv2rgb(h, s, 0.3 + t * 0.7);
            let n = fract(sin(iter * 12.9898 + t * 7823.3) * 43758.5453);
            if (n > 0.98) { c = c + vec3<f32>(1.0 + audio); }
            return c;
        }
    }
}

@compute @workgroup_size(16, 16, 1)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
    let width = u32(view.width);
    let height = u32(view.height);

    if (gid.x >= width || gid.y >= height) { return; }

    let aspect = view.width / view.height;
    let scale = 3.5 / view.zoom;
    let u = f32(gid.x) / view.width - 0.5;
    let v = f32(gid.y) / view.height - 0.5;
    let c = vec2<f32>(
        u * scale * aspect + view.center.x,
        v * scale + view.center.y
    );

    var z = vec2<f32>(0.0, 0.0);
    let jc = vec2<f32>(view.julia_re, view.julia_im);

    // For Julia, start with c as z
    if (view.fractal_type == 1) {
        z = c;
    }

    var iter: f32 = 0.0;
    let max_i = i32(view.max_iter);

    for (var i: i32 = 0; i < max_i; i = i + 1) {
        let zsq = z.x * z.x + z.y * z.y;
        if (zsq > 4.0) { break; }

        switch(view.fractal_type) {
            case 0: { z = mandelbrot(z, c); }
            case 1: { z = julia(z, jc); }
            case 2: { z = burning_ship(z, c); }
            case 3: { z = tricorn(z, c); }
            default: { z = mandelbrot(z, c); }
        }
        iter = iter + 1.0;
    }

    // Smooth iteration
    let zmag = sqrt(z.x * z.x + z.y * z.y);
    var smooth_i = iter;
    if (iter < view.max_iter && zmag > 1.0) {
        smooth_i = iter + 1.0 - log2(log2(zmag));
    }

    // Color
    var color: vec4<f32>;
    if (iter >= view.max_iter) {
        color = vec4<f32>(0.0, 0.0, 0.0, 1.0);
    } else {
        let t = smooth_i / view.max_iter;
        let rgb = get_color(view.color_scheme, t, iter, view.time, view.audio_intensity);
        color = vec4<f32>(rgb, 1.0);
    }

    textureStore(output_texture, vec2<i32>(gid.xy), color);
}
