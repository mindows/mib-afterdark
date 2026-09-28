#version 440
// Demo-scene plasma: four interfering sine fields, coloured through a cosine
// palette (a + b * cos(2pi * (c * t + d))) so every palette is four vectors.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float time;
  float scanlines;
  vec2 resolution;
  vec4 pa;
  vec4 pb;
  vec4 pc;
  vec4 pd;
};

void main() {
  vec2 frag = qt_TexCoord0 * resolution;
  vec2 p = frag / resolution.y * 3.0;
  float t = time * 0.6;
  float v = sin(p.x * 1.6 + t);
  v += sin((p.y * 1.3 + t) * 0.9);
  v += sin((p.x + p.y + t * 1.3) * 0.8);
  vec2 c = p + vec2(sin(t * 0.33) * 2.0, cos(t * 0.5) * 1.5);
  v += sin(sqrt(dot(c, c) + 1.0) * 2.2 - t);
  float k = v * 0.25 + t * 0.05;
  vec3 color = pa.rgb + pb.rgb * cos(6.28318 * (pc.rgb * k + pd.rgb));
  // A light scanline every other row, for the CRT this ran on. The effect
  // is drawn at half resolution, so each row here is two on screen.
  float line = mod(floor(frag.y), 2.0);
  color *= 1.0 - scanlines * 0.22 * line;
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0) * qt_Opacity;
}
