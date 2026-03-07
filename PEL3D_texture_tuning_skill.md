# PEL3D Figure Texture Tuning Skill

## Goal
Create a publication-quality 3D energy landscape figure by improving visual style only:
- Keep geometry unchanged (`x`, `y`, `z` generation unchanged)
- Keep crop range unchanged (`pad_left/right/top/bottom`)
- Keep view-angle logic unchanged (`view_mode`, az/el rotation, top-down tilt)
- Only tune color, lighting, material, texture, and overlay rendering

## Core Rule (Do Not Break)
Never change:
- Surface shape/function
- Landscape cut range
- Camera/view definition

Only change:
- Colormap and contrast
- Lighting/material
- Marker and trace rendering style
- Render order and depth separation

---

## Workflow Used (Step-by-Step)

### 1) Upgrade base surface from sketch to journal style
- Replace raw wire look with shaded `surf(...)` as primary object.
- Use a dark gray + cool tint colormap (metal-like landscape).
- Add balanced lights (`camlight`) and `gouraud` shading.
- Reduce over-bright highlights by lowering specular strength and compressing bright colormap range.

Result: clean, smooth, non-cartoon surface suitable for paper figures.

### 2) Fix overlay defects (dark dots on traces)
Observed issue:
- Trace looked impure with black dots/patches.

Root cause:
- Z-fighting (trace and surface almost same depth)
- Overly complex/translucent overlays

Fix:
- Increase trace sample density.
- Lift traces and markers slightly above surface (`trace_lift`, `marker_lift` based on `z_span`).
- Use clean solid strokes for traces.
- Draw markers after traces so markers stay on top.

### 3) Replace flat markers/traces with real 3D objects
- Dots -> textured 3D balls (`surf` from `sphere(...)`)
- Lines -> textured 3D ropes/tubes (`surf` around path centerline)
- Add helper functions:
  - `add_textured_rope(...)`
  - `add_textured_ball(...)`

### 4) Remove black contamination from rope/ball
- Keep texture bright-only (no dark modulation dips).
- Raise ambient, lower harsh specular on rope/ball.
- Keep object colors clean and saturated.

### 5) Improve true 3D perception
- Increase rope section count and radius.
- Increase sphere resolution.
- Use stable tube frame along path (parallel transport style) so rope does not flatten visually.
- Tune object-only specular/diffuse to reveal roundness.

### 6) Add subtle surface grid
- Re-enable surface edges with low-alpha, thin line width for a technical/journal look.
- Keep grid subtle to avoid competing with rope/ball.

### 7) Enforce geometric alignment between balls and ropes
- Set ball centers directly from rope centerline endpoints.
- Shared endpoint ball center computed from both trace endpoints.
- Keep rope radius unchanged while adjusting ball radius independently.

---

## Practical Parameter Strategy

Use these as tuning knobs:

- **Surface roughness / glare**
  - `SpecularStrength` down -> less shiny
  - `DiffuseStrength` down + `AmbientStrength` up -> softer bright areas
- **Trace purity**
  - Increase `trace_lift`
  - Avoid transparency-heavy multi-layer lines
- **Marker readability**
  - Draw markers last
  - `marker_lift > trace_lift`
- **3D feel**
  - Rope: increase `n_sections` and `rope_radius`
  - Ball: increase sphere resolution
  - Keep modest specular to reveal curvature, not mirror glare
- **Grid strength**
  - `EdgeAlpha` and `LineWidth` control technical look intensity

---

## Artifact -> Fix Cheat Sheet

- **Black speckles on trace**
  - Increase `trace_lift`
  - Simplify line style, avoid alpha blending
  - Reduce surface edge dominance if needed

- **Ball not covering rope endpoint**
  - Render balls after ropes
  - Align ball center exactly to rope centerline endpoint
  - Ensure `marker_lift >= trace_lift`

- **Looks too shiny**
  - Lower `SpecularStrength`
  - Lower bright-end colormap contrast
  - Slightly reduce aggressive fill light

- **Looks flat (paper-like)**
  - Improve rope frame construction
  - Increase rope tube sections/radius
  - Increase sphere resolution and roundness lighting cues

---

## Verification Command
Use this exact command after each significant visual change:

```bash
matlab -batch "PEL3D; exportgraphics(gcf, 'PEL3D_figure.png', 'Resolution', 300);"
```

Then inspect `PEL3D_figure.png` for:
- highlight control
- trace purity
- ball/rope 3D volume
- endpoint alignment
- grid subtlety

---

## Recommended Iteration Loop
1. Change one visual group only (surface, rope, or ball).
2. Export at target resolution.
3. Check for artifacts.
4. Keep if improved; otherwise revert that small block only.

This keeps figure quality high while guaranteeing geometry/view constraints are preserved.
