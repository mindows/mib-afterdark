#version 440
// A polar starfield: the screen is cut into angular sectors, each sector
// holds one star per layer, and every star slides outward along its ray as it
// nears the viewer. Speed stretches stars into streaks. Each pixel only looks
// at its own sector and its neighbours, so the cost is flat per pixel.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float travel;
  float speed;
  float hyper;
  float hue;
  float density;
  vec2 resolution;
};

const float TAU = 6.2831853;
const int LAYERS = 5;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec3 hsv(float h, float s, float v) {
  vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
  return v * mix(vec3(1.0), k, s);
}

void main() {
  vec2 frag = qt_TexCoord0 * resolution;
  vec2 p = (frag - 0.5 * resolution) / resolution.y;
  float r = length(p);
  float a = atan(p.y, p.x) / TAU + 0.5;
  float sectors = density;
  float pixel = 1.0 / resolution.y;
  vec3 color = vec3(0.0);

  for (int layer = 0; layer < LAYERS; layer++) {
    float fl = float(layer);
    for (int n = -1; n <= 1; n++) {
      float sector = floor(a * sectors) + float(n);
      vec2 id = vec2(sector, fl);
      float h1 = hash(id);
      float h2 = hash(id + 17.3);
      // Depth: 0 far away, 1 at the viewer.
      float z = fract(h1 + travel * (0.35 + 0.3 * h2));
      float starAngle = (sector + 0.15 + 0.7 * h2) / sectors;
      float radius = 0.02 * z / max(0.02, 1.0 - z);
      // Streaks grow with the square of speed: points at cruise, lines at warp.
      float tail = radius * clamp(speed * speed, 0.0, 3.0) * 0.4 + pixel;
      float along = r - radius;
      float da = abs(fract(a - starAngle + 0.5) - 0.5) * TAU * r;
      float width = pixel * (0.6 + z * 2.2);
      if (along < pixel && along > -tail - pixel) {
        float core = 1.0 - smoothstep(width * 0.5, width * 1.5, da);
        float fadeTail = 1.0 - clamp(-along / (tail + pixel), 0.0, 1.0);
        // Distant stars fade in, so the vanishing point stays dark.
        float bright = core * fadeTail * smoothstep(0.3, 0.7, z);
        vec3 tint = mix(vec3(0.85, 0.9, 1.0), hsv(fract(hue + h2 * 0.25), 0.7, 1.0), hyper);
        color += tint * bright * (0.5 + z);
      }
    }
  }
  fragColor = vec4(min(color, vec3(1.0)), 1.0) * qt_Opacity;
}
