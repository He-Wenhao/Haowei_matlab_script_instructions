# Haowei MATLAB Surface Figure

This project generates a styled 3D potential/energy landscape figure with:
- a shaded surface
- two 3D rope-like traces
- three 3D ball markers

The main script is `PEL3D.m`.

## Requirements

- MATLAB (tested with batch execution)
- Files in the same folder:
  - `PEL3D.m`
  - `PEL3D_random_params.mat` (optional if regenerating random params)

## Quick Start

Run from this directory in terminal:

```bash
matlab -batch "PEL3D"
```

This opens/renders the figure according to parameters inside `PEL3D.m`.

## Export Figure (Recommended)

Use this command to render and export a high-resolution PNG:

```bash
matlab -batch "PEL3D; exportgraphics(gcf, 'PEL3D_figure.png', 'Resolution', 300);"
```

Output file:
- `PEL3D_figure.png`

## Common Parameters to Edit

Inside `PEL3D.m`, you can adjust:

- Reproducibility:
  - `random_mode` (`"load"` or `"generate"`)
  - `random_param_file`
- View controls:
  - `view_mode`
  - `z_rotation_deg`
  - `topdown_tilt_deg`
- Surface crop window:
  - `pad_left`, `pad_right`, `pad_bottom`, `pad_top`
- Styling:
  - surface lighting/material/colormap
  - `rope_radius`
  - `ball_radius`

## Notes

- The script is designed so geometry/view logic can stay fixed while visual style is tuned.
- If you want a process guide for texture/style tuning, see:
  - `PEL3D_texture_tuning_skill.md`
