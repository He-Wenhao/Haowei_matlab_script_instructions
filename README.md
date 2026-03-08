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

This runs the **original** surface mode and renders the figure according to parameters inside `PEL3D.m`.

## Switch Modes: Original vs LM

`PEL3D.m` now supports two modes:

- **Original mode** (single minimum behavior):
  - Call: `PEL3D()`
  - Batch command:
    ```bash
    matlab -batch "PEL3D"
    ```
- **LM mode** (split local minima behavior):
  - Call: `PEL3D('lm')`
  - Batch command:
    ```bash
    matlab -batch "PEL3D('lm')"
    ```

Recommended export commands:

```bash
# Original
matlab -batch "PEL3D; exportgraphics(gcf, 'PEL3D_figure.png', 'Resolution', 300);"

# LM variant
matlab -batch "PEL3D('lm'); exportgraphics(gcf, 'PEL3D_lm_figure.png', 'Resolution', 300);"
```

## Export Figure (Recommended)

Use this command to render and export a high-resolution PNG:

```bash
matlab -batch "PEL3D; exportgraphics(gcf, 'PEL3D_figure.png', 'Resolution', 300);"
```

Output file:
- `PEL3D_figure.png`
- `PEL3D_lm_figure.png` (if LM mode is used)

## Common Parameters to Edit

Inside `PEL3D.m`, edit values in `build_config(...)`:

- Reproducibility:
  - `cfg.random_mode` (`"load"` or `"generate"`)
  - `cfg.random_param_file`
- View controls:
  - `cfg.view_mode`
  - `cfg.z_rotation_deg`
  - `cfg.topdown_tilt_deg`
- Surface crop window:
  - `cfg.pad_left`, `cfg.pad_right`, `cfg.pad_bottom`, `cfg.pad_top`
- LM split controls:
  - `cfg.lm_split_distance`
  - `cfg.lm_sigma`
  - `cfg.lm_well_depth_ratio`
  - `cfg.lm_center_ridge_ratio`
- Styling:
  - surface lighting/material/colormap
  - `cfg.rope_radius`
  - `cfg.ball_radius`

## Notes

- The script is designed so geometry/view logic can stay fixed while visual style is tuned.
- If you want a process guide for texture/style tuning, see:
  - `PEL3D_texture_tuning_skill.md`
