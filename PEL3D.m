%% 
clear;

% Reproducible random parameter control
random_mode = "load"; % "generate" or "load"
view_mode = "default"; % "default" or "z_axis"
z_rotation_deg = -150; % rotate camera around z axis (azimuth)
topdown_tilt_deg = 25; % increase elevation for a more top-down view
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

% Smooth shaded surface with a subtle edge texture.
surf_obj = surf(ax, x, y, z, z, ...
    "EdgeColor", [0 0 0], ...
    "EdgeAlpha", 0.08, ...
    "FaceColor", "interp", ...
    "FaceLighting", "gouraud", ...
    "SpecularStrength", 0.06, ...
    "SpecularExponent", 8, ...
    "DiffuseStrength", 0.86, ...
    "AmbientStrength", 0.52);

% Journal-style dark gray landscape with cool highlights near valleys.
gray_cmap = gray(256);
gray_cmap = 0.17 + 0.70 * gray_cmap;
cool_tint = [linspace(0.00, 0.02, 256)', ...
             linspace(0.06, 0.20, 256)', ...
             linspace(0.08, 0.36, 256)'];
landscape_cmap = min(gray_cmap + 0.55 * cool_tint, 1);
colormap(ax, landscape_cmap);

z_min = min(z(:));
z_max = max(z(:));
if z_max > z_min
    caxis(ax, [z_min, z_max]);
end

lighting(ax, "gouraud");
material(ax, [0.45 0.85 0.05 8 0.7]);
camlight(ax, "headlight");
camlight(ax, 35, 20);
camlight(ax, -60, -12);
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

% Mark the three points with soft halo + bright core.
mk1 = [0.00, 0.88, 0.70]; % teal
mk2 = [0.20, 0.70, 1.00]; % cyan-blue
mk3 = [1.00, 0.28, 0.25]; % red
scatter3(ax, init_pt_1(1), init_pt_1(2), init_z_1, 260, mk1, ...
    "filled", "MarkerFaceAlpha", 0.20, "MarkerEdgeAlpha", 0.00);
scatter3(ax, init_pt_2(1), init_pt_2(2), init_z_2, 260, mk2, ...
    "filled", "MarkerFaceAlpha", 0.20, "MarkerEdgeAlpha", 0.00);
scatter3(ax, min_pt(1), min_pt(2), min_z, 320, mk3, ...
    "filled", "MarkerFaceAlpha", 0.26, "MarkerEdgeAlpha", 0.00);
scatter3(ax, init_pt_1(1), init_pt_1(2), init_z_1, 68, mk1, ...
    "filled", "MarkerEdgeColor", [0.95 0.95 0.95], "LineWidth", 0.9);
scatter3(ax, init_pt_2(1), init_pt_2(2), init_z_2, 68, mk2, ...
    "filled", "MarkerEdgeColor", [0.95 0.95 0.95], "LineWidth", 0.9);
scatter3(ax, min_pt(1), min_pt(2), min_z, 86, mk3, ...
    "filled", "MarkerEdgeColor", [1 1 1], "LineWidth", 1.0);

% Create two optimization traces on the surface
n_trace = 120;
t = linspace(0, 1, n_trace);

trace1_x = init_pt_1(1) + (min_pt(1) - init_pt_1(1)) * t;
trace1_y = init_pt_1(2) + (min_pt(2) - init_pt_1(2)) * t;
trace1_z = interp2(x, y, z, trace1_x, trace1_y, "linear");

trace2_x = init_pt_2(1) + (min_pt(1) - init_pt_2(1)) * t;
trace2_y = init_pt_2(2) + (min_pt(2) - init_pt_2(2)) * t;
trace2_z = interp2(x, y, z, trace2_x, trace2_y, "linear");

% Traces with soft glow underlay + crisp core line.
plot3(ax, trace1_x, trace1_y, trace1_z, "-", ...
    "Color", [0.45 1.00 0.85], "LineWidth", 8.0);
plot3(ax, trace2_x, trace2_y, trace2_z, "-", ...
    "Color", [0.55 0.90 1.00], "LineWidth", 8.0);
plot3(ax, trace1_x, trace1_y, trace1_z, "-", ...
    "Color", [0.05 0.96 0.78], "LineWidth", 3.0);
plot3(ax, trace2_x, trace2_y, trace2_z, "-", ...
    "Color", [0.24 0.80 1.00], "LineWidth", 3.0);

hold(ax, "off");