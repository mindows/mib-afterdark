#version 440
// Code rain on the GPU. The screen is a grid of cells; each column has its
// own speed and phase, a bright head, and a trail that fades above it. Each
// cell shows one glyph from a small atlas (rendered once from real text), and
// now and then swaps it for another.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float time;
  float cell;
  float trail;
  float glyphCount;
  vec2 resolution;
};

layout(binding = 1) uniform sampler2D atlas;

float hash(vec2 p) {
  p = fract(p * vec2(233.34, 851.73));
  p += dot(p, p + 23.45);
  return fract(p.x * p.y);
}

void main() {
  vec2 frag = qt_TexCoord0 * resolution;
  vec2 id = floor(frag / cell);
  vec2 local = fract(frag / cell);
  float rows = ceil(resolution.y / cell);

  float speed = mix(8.0, 22.0, hash(vec2(id.x, 3.1)));
  float span = rows + trail * 1.5;
  float head = mod(time * speed + hash(vec2(id.x, 7.7)) * span, span) - trail * 0.25;
  float d = floor(head) - id.y;

  vec3 color = vec3(0.0);
  if (d >= 0.0 && d < trail) {
    // A glyph that changes now and then, each cell on its own clock.
    float tick = floor(time * mix(0.3, 2.0, hash(id + 0.5)) + hash(id) * 10.0);
    float index = floor(hash(id + tick * 0.137) * glyphCount);
    vec2 atlasCell = vec2(mod(index, 8.0), floor(index / 8.0));
    float ink = texture(atlas, (atlasCell + local) / 8.0).a;
    if (d < 1.0) {
      color = vec3(0.91, 1.0, 0.94) * ink;
    } else {
      float fade = pow(1.0 - d / trail, 1.6);
      color = vec3(0.1, 0.79, 0.29) * ink * fade;
    }
  }
  fragColor = vec4(color, 1.0) * qt_Opacity;
}
