%% 
clear;

% Reproducible random parameter control
random_mode = "load"; % "generate" or "load"
view_mode = "default"; % "default" or "z_axis"
z_rotation_deg = -140; % rotate camera around z axis (azimuth)
topdown_tilt_deg = 10; % increase elevation for a more top-down view
random_param_file = "PEL3D_random_params.mat";
pad_left = 50;
pad_right = 25;
pad_bottom = 20;
pad_top = 20;
N = 100;
if (1 + pad_left) > (N - pad_right) || (1 + pad_bottom) > (N - pad_top)
    error("Padding is too large and leaves an empty grid.");
end
x_vals = (1 + pad_left):(N - pad_right);
y_vals = (1 + pad_bottom):(N - pad_top);
[x, y] = meshgrid(x_vals, y_vals);
grid_rows = size(x, 1);
grid_cols = size(x, 2);

if random_mode == "load" && isfile(random_param_file)
    loaded_data = load(random_param_file, "random_params");
    random_params = loaded_data.random_params;
    if ~isfield(random_params, "N")
        error("Saved random parameters are missing field N.");
    end
    if random_params.N ~= N
        error("Saved random parameters use N=%d, but current N=%d.", random_params.N, N);
    end
    if ~isfield(random_params, "grid_rows") || ~isfield(random_params, "grid_cols") ...
            || random_params.grid_rows ~= grid_rows || random_params.grid_cols ~= grid_cols ...
            || ~isfield(random_params, "rand_term_1") || ~isfield(random_params, "rand_term_2") ...
            || ~isequal(size(random_params.rand_term_1), [grid_rows, grid_cols]) ...
            || ~isequal(size(random_params.rand_term_2), [grid_rows, grid_cols])
        warning("Saved random parameters are incompatible with current grid; regenerating.");
        random_params.rand_term_1 = rand(grid_rows, grid_cols);
        random_params.rand_term_2 = rand(grid_rows, grid_cols);
        random_params.N = N;
        random_params.grid_rows = grid_rows;
        random_params.grid_cols = grid_cols;
    end
else
    random_params.rand_term_1 = rand(grid_rows, grid_cols);
    random_params.rand_term_2 = rand(grid_rows, grid_cols);
    random_params.N = N;
    random_params.grid_rows = grid_rows;
    random_params.grid_cols = grid_cols;
end

z = ((sin(5*x./N)+1).*(cos(15*y./N)-1) + 10*random_params.rand_term_1)...
    .*((cos(5*y./N)-1).*(sin(15*x./N)+1) + 10*random_params.rand_term_2);

% Save the exact random values used in this run.
save(random_param_file, "random_params");

% z = ((sin(2*x./N)+1).*(cos(2*y./N)-1) + 2*rand(1, N))...
%     .*((cos(2*y./N)-1).*(sin(2*x./N)+1) + 2*rand(1, N));



zz = fft2(z);
zzz = zeros(size(z));
n = 2;
zzz(1:n, 1:n) = zz(1:n, 1:n);
z = ifft2(zzz);

z = real(z);
fig = figure("Color", [0.96 0.96 0.96]);
ax = axes(fig);
hold(ax, "on");
set(fig, "Renderer", "opengl");

% Smooth shaded surface with a subtle edge texture.
surf_obj = surf(ax, x, y, z, z, ...
    "EdgeColor", "none", ...
    "FaceColor", "interp", ...
    "FaceLighting", "gouraud", ...
    "SpecularStrength", 0.02, ...
    "SpecularExponent", 8, ...
    "DiffuseStrength", 0.68, ...
    "AmbientStrength", 0.62);

% Journal-style dark gray landscape with cool highlights near valleys.
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
if view_mode == "default"
    view(3);
elseif view_mode == "z_axis"
    view(2);
else
    error("Unknown view_mode: %s. Use 'default' or 'z_axis'.", view_mode);
end
[az, el] = view;
view(az + z_rotation_deg, min(el + topdown_tilt_deg, 89));
set(gcf, "Color", [0.96 0.96 0.96]);
axis(ax, "off");
axis(ax, "tight");

% Two initial points; minimum point will be computed from the surface
init_pt_1 = [69, 36];
init_pt_2 = [57, 46];

% Find the true minimum point on the current surface z
[min_z, min_idx] = min(z(:));
[min_row, min_col] = ind2sub(size(z), min_idx);
min_pt = [x(min_row, min_col), y(min_row, min_col)];

% Sample z from the current surface so markers/traces stay on the mesh
init_z_1 = interp2(x, y, z, init_pt_1(1), init_pt_1(2), "linear");
init_z_2 = interp2(x, y, z, init_pt_2(1), init_pt_2(2), "linear");
z_span = z_max - z_min;
if z_span <= 0
    z_span = 1;
end
trace_lift = 0.012 * z_span;
marker_lift = 0.018 * z_span;
trace_lift = 0.050 * z_span;
marker_lift = 0.070 * z_span;
rope_radius = 0.30;
ball_radius = 0.42;

% Create two optimization traces on the surface
n_trace = 420;
t = linspace(0, 1, n_trace);

trace1_x = init_pt_1(1) + (min_pt(1) - init_pt_1(1)) * t;
trace1_y = init_pt_1(2) + (min_pt(2) - init_pt_1(2)) * t;
trace1_z = interp2(x, y, z, trace1_x, trace1_y, "makima");
if any(isnan(trace1_z))
    trace1_z = interp2(x, y, z, trace1_x, trace1_y, "linear");
end

trace2_x = init_pt_2(1) + (min_pt(1) - init_pt_2(1)) * t;
trace2_y = init_pt_2(2) + (min_pt(2) - init_pt_2(2)) * t;
trace2_z = interp2(x, y, z, trace2_x, trace2_y, "makima");
if any(isnan(trace2_z))
    trace2_z = interp2(x, y, z, trace2_x, trace2_y, "linear");
end

% Build 3D rope traces (tube surfaces with texture).
trace1_path = [trace1_x(:), trace1_y(:), trace1_z(:) + trace_lift];
trace2_path = [trace2_x(:), trace2_y(:), trace2_z(:) + trace_lift];
add_textured_rope(ax, trace1_path, rope_radius, [0.06 0.95 0.78]);
add_textured_rope(ax, trace2_path, rope_radius, [0.24 0.80 1.00]);

% Draw 3D balls last so they stay on the top visual layer.
mk1 = [0.00, 0.88, 0.70]; % teal
mk2 = [0.20, 0.70, 1.00]; % cyan-blue
mk3 = [1.00, 0.28, 0.25]; % red
ball1_center = trace1_path(1, :); % align with rope 1 start centerline
ball2_center = trace2_path(1, :); % align with rope 2 start centerline
ball3_center = 0.5 * (trace1_path(end, :) + trace2_path(end, :)); % shared end center
add_textured_ball(ax, ball1_center, ball_radius, mk1);
add_textured_ball(ax, ball2_center, ball_radius, mk2);
add_textured_ball(ax, ball3_center, 1.08 * ball_radius, mk3);

hold(ax, "off");

function add_textured_rope(ax, path_xyz, radius, base_color)
% Build a tube around a 3D path with bright, clean texture.
n_sections = 40;
theta = linspace(0, 2*pi, n_sections + 1);
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
twist_v = repmat(theta / (2*pi), n_pts, 1);
braid = 1.00 + 0.02 * sin(2*pi * (7.0 * twist_u + 2.0 * twist_v));
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