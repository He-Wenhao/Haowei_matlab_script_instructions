function PEL3D(mode)
%PEL3D Generate a textured 3D energy landscape and traces.
%Single-file function-based design so config objects can be changed easily.

if nargin < 1
    mode = "original";
end
mode = string(mode);

cfg = build_config(mode);
grid = build_grid(cfg);
rand_obj = resolve_random_params(cfg, grid);
surface_obj = build_surface(cfg, grid, rand_obj);
random_params = rand_obj; %#ok<NASGU> % backward-compatible variable name
save(cfg.random_param_file, "rand_obj", "random_params");

scene = build_scene(cfg, grid, surface_obj.z);
overlay = build_overlay(cfg, grid, surface_obj, scene.z_min, scene.z_max);
draw_overlay(scene.ax, overlay);
end

function cfg = build_config(mode)
cfg = struct();

% Reproducible random parameter control.
cfg.random_mode = "load"; % "generate" or "load"
cfg.random_param_file = "PEL3D_random_params.mat";

% Camera/view controls.
cfg.view_mode = "default"; % "default" or "z_axis"
cfg.z_rotation_deg = -140; % rotate camera around z axis (azimuth)
cfg.topdown_tilt_deg = 10; % increase elevation for a more top-down view

% Grid controls.
cfg.N = 100;
cfg.pad_left = 50;
cfg.pad_right = 25;
cfg.pad_bottom = 20;
cfg.pad_top = 20;

% Frequency-domain smoothing.
cfg.lowpass_n = 2;

% Overlay/trace controls.
cfg.init_pt_1 = [69, 36];
cfg.init_pt_2 = [57, 46];
cfg.n_trace = 420;
cfg.rope_radius = 0.30;
cfg.ball_radius = 0.42;
cfg.trace_lift_ratio = 0.050;
cfg.ball3_scale = 1.08;

% Appearance controls.
cfg.figure_bg = [0.96 0.96 0.96];
cfg.rope_color_1 = [0.06 0.95 0.78];
cfg.rope_color_2 = [0.24 0.80 1.00];
cfg.ball_color_1 = [0.00 0.88 0.70];
cfg.ball_color_2 = [0.20 0.70 1.00];
cfg.ball_color_3 = [1.00 0.28 0.25];

% Surface variant controls.
cfg.surface_variant = mode; % "original" or "lm"
cfg.lm_split_distance = 3.0; % center-to-center split distance (grid units)
cfg.lm_sigma = 1.15; % local minimum footprint
cfg.lm_well_depth_ratio = 0.12; % relative to z span
cfg.lm_center_ridge_ratio = 0.75; % central bump to separate two minima
cfg.lm_search_radius = 2.8; % radius to capture each local minimum
end

function grid = build_grid(cfg)
if (1 + cfg.pad_left) > (cfg.N - cfg.pad_right) || ...
        (1 + cfg.pad_bottom) > (cfg.N - cfg.pad_top)
    error("Padding is too large and leaves an empty grid.");
end

x_vals = (1 + cfg.pad_left):(cfg.N - cfg.pad_right);
y_vals = (1 + cfg.pad_bottom):(cfg.N - cfg.pad_top);
[x, y] = meshgrid(x_vals, y_vals);

grid = struct();
grid.x = x;
grid.y = y;
grid.rows = size(x, 1);
grid.cols = size(x, 2);
end

function rand_obj = resolve_random_params(cfg, grid)
should_load = cfg.random_mode == "load" && isfile(cfg.random_param_file);

if should_load
    loaded_data = load(cfg.random_param_file);
    if isfield(loaded_data, "rand_obj")
        candidate = loaded_data.rand_obj;
    elseif isfield(loaded_data, "random_params")
        % Backward compatibility with older saved variable name.
        candidate = loaded_data.random_params;
    else
        candidate = struct();
    end

    if is_random_obj_compatible(candidate, cfg, grid)
        rand_obj = candidate;
        return;
    end
    warning("Saved random parameters are incompatible with current grid; regenerating.");
end

rand_obj = make_random_obj(cfg, grid);
end

function ok = is_random_obj_compatible(rand_obj, cfg, grid)
ok = isfield(rand_obj, "N") && rand_obj.N == cfg.N && ...
    isfield(rand_obj, "grid_rows") && rand_obj.grid_rows == grid.rows && ...
    isfield(rand_obj, "grid_cols") && rand_obj.grid_cols == grid.cols && ...
    isfield(rand_obj, "rand_term_1") && ...
    isequal(size(rand_obj.rand_term_1), [grid.rows, grid.cols]) && ...
    isfield(rand_obj, "rand_term_2") && ...
    isequal(size(rand_obj.rand_term_2), [grid.rows, grid.cols]);
end

function rand_obj = make_random_obj(cfg, grid)
rand_obj = struct();
rand_obj.rand_term_1 = rand(grid.rows, grid.cols);
rand_obj.rand_term_2 = rand(grid.rows, grid.cols);
rand_obj.N = cfg.N;
rand_obj.grid_rows = grid.rows;
rand_obj.grid_cols = grid.cols;
end

function surface_obj = build_surface(cfg, grid, rand_obj)
z = ((sin(5 * grid.x ./ cfg.N) + 1) .* (cos(15 * grid.y ./ cfg.N) - 1) + ...
    10 * rand_obj.rand_term_1) .* ...
    ((cos(5 * grid.y ./ cfg.N) - 1) .* (sin(15 * grid.x ./ cfg.N) + 1) + ...
    10 * rand_obj.rand_term_2);

% Low-pass filter in frequency domain.
zz = fft2(z);
zzz = zeros(size(z));
zzz(1:cfg.lowpass_n, 1:cfg.lowpass_n) = zz(1:cfg.lowpass_n, 1:cfg.lowpass_n);
z = real(ifft2(zzz));

surface_obj = struct();
surface_obj.z = z;
surface_obj.has_split_minima = false;
surface_obj.lm_min_1 = struct();
surface_obj.lm_min_2 = struct();

if cfg.surface_variant == "lm"
    [z_lm, lm_min_1, lm_min_2] = apply_lm_split(cfg, grid, z);
    surface_obj.z = z_lm;
    surface_obj.has_split_minima = true;
    surface_obj.lm_min_1 = lm_min_1;
    surface_obj.lm_min_2 = lm_min_2;
elseif cfg.surface_variant ~= "original"
    error("Unknown surface_variant: %s. Use 'original' or 'lm'.", cfg.surface_variant);
end
end

function [z_lm, lm_min_1, lm_min_2] = apply_lm_split(cfg, grid, z_base)
% Build a tiny double-well near the original minimum.
[~, min_idx] = min(z_base(:));
[min_row, min_col] = ind2sub(size(z_base), min_idx);
min_pt = [grid.x(min_row, min_col), grid.y(min_row, min_col)];

split_axis = cfg.init_pt_2 - cfg.init_pt_1;
if norm(split_axis) < 1e-9
    split_axis = [1, 0];
end
split_axis = split_axis / norm(split_axis);
half_split = 0.5 * cfg.lm_split_distance;

center_1 = min_pt + half_split * split_axis;
center_2 = min_pt - half_split * split_axis;

dx1 = grid.x - center_1(1);
dy1 = grid.y - center_1(2);
dx2 = grid.x - center_2(1);
dy2 = grid.y - center_2(2);
dcx = grid.x - min_pt(1);
dcy = grid.y - min_pt(2);

z_span = max(max(z_base(:)) - min(z_base(:)), 1);
well_depth = cfg.lm_well_depth_ratio * z_span;
ridge_height = cfg.lm_center_ridge_ratio * well_depth;
sigma = cfg.lm_sigma;

well_1 = exp(-(dx1.^2 + dy1.^2) / (2 * sigma^2));
well_2 = exp(-(dx2.^2 + dy2.^2) / (2 * sigma^2));
ridge = exp(-(dcx.^2 + dcy.^2) / (2 * (0.60 * sigma)^2));

z_lm = z_base - well_depth * (well_1 + well_2) + ridge_height * ridge;
lm_min_1 = find_local_min_near(grid, z_lm, center_1, cfg.lm_search_radius);
lm_min_2 = find_local_min_near(grid, z_lm, center_2, cfg.lm_search_radius);
end

function min_obj = find_local_min_near(grid, z, center_xy, search_radius)
dist2 = (grid.x - center_xy(1)).^2 + (grid.y - center_xy(2)).^2;
mask = dist2 <= search_radius^2;

if ~any(mask(:))
    [~, min_idx] = min(dist2(:));
    [row_idx, col_idx] = ind2sub(size(z), min_idx);
else
    z_masked = z;
    z_masked(~mask) = inf;
    [~, min_idx] = min(z_masked(:));
    [row_idx, col_idx] = ind2sub(size(z_masked), min_idx);
end

min_obj = struct();
min_obj.z = z(row_idx, col_idx);
min_obj.point = [grid.x(row_idx, col_idx), grid.y(row_idx, col_idx)];
end

function scene = build_scene(cfg, grid, z)
fig = figure("Color", cfg.figure_bg);
ax = axes(fig);
hold(ax, "on");
set(fig, "Renderer", "opengl");

surf(ax, grid.x, grid.y, z, z, ...
    "EdgeColor", "none", ...
    "FaceColor", "interp", ...
    "FaceLighting", "gouraud", ...
    "SpecularStrength", 0.02, ...
    "SpecularExponent", 8, ...
    "DiffuseStrength", 0.68, ...
    "AmbientStrength", 0.62);

gray_cmap = gray(256);
gray_cmap = 0.20 + 0.64 * gray_cmap;
cool_tint = [linspace(0.00, 0.02, 256)', ...
             linspace(0.06, 0.20, 256)', ...
             linspace(0.08, 0.36, 256)'];
landscape_cmap = min(gray_cmap + 0.45 * cool_tint, 1);
colormap(ax, landscape_cmap);

z_min = min(z(:));
z_max = max(z(:));
if z_max > z_min
    caxis(ax, [z_min, z_max]);
end

lighting(ax, "gouraud");
material(ax, [0.62 0.60 0.02 8 0.9]);
camlight(ax, "headlight");
camlight(ax, 35, 20);
camlight(ax, -45, -8);

set_view(cfg, ax);
set(gcf, "Color", cfg.figure_bg);
axis(ax, "off");
axis(ax, "tight");

scene = struct();
scene.fig = fig;
scene.ax = ax;
scene.z_min = z_min;
scene.z_max = z_max;
end

function set_view(cfg, ax)
if cfg.view_mode == "default"
    view(ax, 3);
elseif cfg.view_mode == "z_axis"
    view(ax, 2);
else
    error("Unknown view_mode: %s. Use 'default' or 'z_axis'.", cfg.view_mode);
end
[az, el] = view(ax);
view(ax, az + cfg.z_rotation_deg, min(el + cfg.topdown_tilt_deg, 89));
end

function overlay = build_overlay(cfg, grid, surface_obj, z_min, z_max)
z = surface_obj.z;
min_obj = find_minimum(grid, z);
z_span = max(z_max - z_min, 1);
trace_lift = cfg.trace_lift_ratio * z_span;

if cfg.surface_variant == "lm"
    lm_pt_1 = surface_obj.lm_min_1.point;
    lm_pt_2 = surface_obj.lm_min_2.point;
    % Choose the endpoint pairing that minimizes total travel distance
    % so the two LM traces do not cross each other.
    pairing_cost_direct = norm(cfg.init_pt_1 - lm_pt_1) + norm(cfg.init_pt_2 - lm_pt_2);
    pairing_cost_swap = norm(cfg.init_pt_1 - lm_pt_2) + norm(cfg.init_pt_2 - lm_pt_1);
    if pairing_cost_swap < pairing_cost_direct
        target_1 = lm_pt_2;
        target_2 = lm_pt_1;
    else
        target_1 = lm_pt_1;
        target_2 = lm_pt_2;
    end
    trace_1 = make_trace(cfg.init_pt_1, target_1, cfg.n_trace, grid, z, trace_lift);
    trace_2 = make_trace(cfg.init_pt_2, target_2, cfg.n_trace, grid, z, trace_lift);
    dual_endpoints = true;
else
    trace_1 = make_trace(cfg.init_pt_1, min_obj.point, cfg.n_trace, grid, z, trace_lift);
    trace_2 = make_trace(cfg.init_pt_2, min_obj.point, cfg.n_trace, grid, z, trace_lift);
    dual_endpoints = false;
end

overlay = struct();
overlay.trace_1 = trace_1;
overlay.trace_2 = trace_2;
overlay.min_obj = min_obj;
overlay.dual_endpoints = dual_endpoints;
overlay.rope_radius = cfg.rope_radius;
overlay.ball_radius = cfg.ball_radius;
overlay.ball3_scale = cfg.ball3_scale;
overlay.rope_color_1 = cfg.rope_color_1;
overlay.rope_color_2 = cfg.rope_color_2;
overlay.ball_color_1 = cfg.ball_color_1;
overlay.ball_color_2 = cfg.ball_color_2;
overlay.ball_color_3 = cfg.ball_color_3;
end

function min_obj = find_minimum(grid, z)
[min_z, min_idx] = min(z(:));
[min_row, min_col] = ind2sub(size(z), min_idx);

min_obj = struct();
min_obj.z = min_z;
min_obj.point = [grid.x(min_row, min_col), grid.y(min_row, min_col)];
end

function trace_obj = make_trace(init_pt, min_pt, n_trace, grid, z, trace_lift)
t = linspace(0, 1, n_trace);
x = init_pt(1) + (min_pt(1) - init_pt(1)) * t;
y = init_pt(2) + (min_pt(2) - init_pt(2)) * t;
z_line = interp2(grid.x, grid.y, z, x, y, "makima");
if any(isnan(z_line))
    z_line = interp2(grid.x, grid.y, z, x, y, "linear");
end

trace_obj = struct();
trace_obj.path = [x(:), y(:), z_line(:) + trace_lift];
end

function draw_overlay(ax, overlay)
add_textured_rope(ax, overlay.trace_1.path, overlay.rope_radius, overlay.rope_color_1);
add_textured_rope(ax, overlay.trace_2.path, overlay.rope_radius, overlay.rope_color_2);

ball1_center = overlay.trace_1.path(1, :);
ball2_center = overlay.trace_2.path(1, :);
ball3_center = 0.5 * (overlay.trace_1.path(end, :) + overlay.trace_2.path(end, :));

add_textured_ball(ax, ball1_center, overlay.ball_radius, overlay.ball_color_1);
add_textured_ball(ax, ball2_center, overlay.ball_radius, overlay.ball_color_2);
if overlay.dual_endpoints
    add_textured_ball(ax, overlay.trace_1.path(end, :), overlay.ball3_scale * overlay.ball_radius, overlay.ball_color_3);
    add_textured_ball(ax, overlay.trace_2.path(end, :), overlay.ball3_scale * overlay.ball_radius, [1.00, 0.55, 0.12]);
else
    add_textured_ball(ax, ball3_center, overlay.ball3_scale * overlay.ball_radius, overlay.ball_color_3);
end

hold(ax, "off");
end

function add_textured_rope(ax, path_xyz, radius, base_color)
% Build a tube around a 3D path with bright, clean texture.
n_sections = 40;
theta = linspace(0, 2 * pi, n_sections + 1);
ct = cos(theta);
st = sin(theta);
n_pts = size(path_xyz, 1);

dp = zeros(n_pts, 3);
dp(1, :) = path_xyz(2, :) - path_xyz(1, :);
dp(end, :) = path_xyz(end, :) - path_xyz(end - 1, :);
dp(2:end-1, :) = 0.5 * (path_xyz(3:end, :) - path_xyz(1:end-2, :));
tangent = dp ./ max(vecnorm(dp, 2, 2), 1e-9);
normal = zeros(n_pts, 3);
binormal = zeros(n_pts, 3);

ref = [0 0 1];
if abs(dot(tangent(1, :), ref)) > 0.92
    ref = [0 1 0];
end
normal(1, :) = cross(tangent(1, :), ref);
normal(1, :) = normal(1, :) ./ max(norm(normal(1, :)), 1e-9);

for i = 2:n_pts
    v_prev = tangent(i - 1, :);
    v_cur = tangent(i, :);
    rot_axis = cross(v_prev, v_cur);
    sin_a = norm(rot_axis);
    cos_a = max(min(dot(v_prev, v_cur), 1), -1);
    n_prev = normal(i - 1, :);
    if sin_a < 1e-10
        n_rot = n_prev;
    else
        k = rot_axis / sin_a;
        ang = atan2(sin_a, cos_a);
        n_rot = n_prev * cos(ang) + cross(k, n_prev) * sin(ang) + ...
            k * dot(k, n_prev) * (1 - cos(ang));
    end
    n_rot = n_rot ./ max(norm(n_rot), 1e-9);
    b_vec = cross(v_cur, n_rot);
    b_vec = b_vec ./ max(norm(b_vec), 1e-9);
    normal(i, :) = cross(b_vec, v_cur);
    normal(i, :) = normal(i, :) ./ max(norm(normal(i, :)), 1e-9);
    binormal(i, :) = b_vec;
end
binormal(1, :) = cross(tangent(1, :), normal(1, :));
binormal(1, :) = binormal(1, :) ./ max(norm(binormal(1, :)), 1e-9);

X = path_xyz(:, 1) + radius * (normal(:, 1) * ct + binormal(:, 1) * st);
Y = path_xyz(:, 2) + radius * (normal(:, 2) * ct + binormal(:, 2) * st);
Z = path_xyz(:, 3) + radius * (normal(:, 3) * ct + binormal(:, 3) * st);

arc_s = [0; cumsum(vecnorm(diff(path_xyz, 1, 1), 2, 2))];
arc_s = arc_s / max(arc_s(end), 1e-9);
twist_u = repmat(arc_s, 1, n_sections + 1);
twist_v = repmat(theta / (2 * pi), n_pts, 1);
braid = 1.00 + 0.02 * sin(2 * pi * (7.0 * twist_u + 2.0 * twist_v));
texture_gain = max(0.98, braid);

C = zeros(n_pts, n_sections + 1, 3);
for k = 1:3
    C(:, :, k) = min(1, max(0, base_color(k) .* texture_gain + 0.02));
end

surf(ax, X, Y, Z, C, ...
    "FaceColor", "texturemap", ...
    "EdgeColor", "none", ...
    "FaceLighting", "gouraud", ...
    "SpecularStrength", 0.08, ...
    "SpecularExponent", 18, ...
    "DiffuseStrength", 0.72, ...
    "AmbientStrength", 0.62);
end

function add_textured_ball(ax, center_xyz, radius, base_color)
% Draw a clean sphere marker with gentle bright texture.
res = 56;
[sx, sy, sz] = sphere(res);
X = center_xyz(1) + radius * sx;
Y = center_xyz(2) + radius * sy;
Z = center_xyz(3) + radius * sz;

phi = atan2(sy, sx);
micro = 1.00 + 0.015 * sin(6 * phi) .* (0.85 + 0.15 * cos(5 * sz));
light_dir = 0.55 * sx + 0.15 * sy + 0.82 * sz;
hemi = 0.99 + 0.04 * max(light_dir, 0);
texture_gain = max(0.98, micro .* hemi);

C = zeros(size(sx, 1), size(sx, 2), 3);
for k = 1:3
    C(:, :, k) = min(1, max(0, base_color(k) .* texture_gain + 0.02));
end

surf(ax, X, Y, Z, C, ...
    "FaceColor", "texturemap", ...
    "EdgeColor", "none", ...
    "FaceLighting", "gouraud", ...
    "SpecularStrength", 0.10, ...
    "SpecularExponent", 24, ...
    "DiffuseStrength", 0.70, ...
    "AmbientStrength", 0.66);
end