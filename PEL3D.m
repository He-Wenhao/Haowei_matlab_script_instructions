%% 
clear;

% Reproducible random parameter control
random_mode = "load"; % "generate" or "load"
view_mode = "z_axis"; % "default" or "z_axis"
random_param_file = "PEL3D_random_params.mat";
pad_left = 20;
pad_right = 20;
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
mesh(x, y, z);
if view_mode == "default"
    view(3);
elseif view_mode == "z_axis"
    view(2);
else
    error("Unknown view_mode: %s. Use 'default' or 'z_axis'.", view_mode);
end
set(gcf, 'Color', 'none');
axis off
hold on;

% Two initial points; minimum point will be computed from the surface
init_pt_1 = [77, 36];
init_pt_2 = [47, 37];

% Find the true minimum point on the current surface z
[min_z, min_idx] = min(z(:));
[min_row, min_col] = ind2sub(size(z), min_idx);
min_pt = [x(min_row, min_col), y(min_row, min_col)];

% Sample z from the current surface so markers/traces stay on the mesh
init_z_1 = interp2(x, y, z, init_pt_1(1), init_pt_1(2), "linear");
init_z_2 = interp2(x, y, z, init_pt_2(1), init_pt_2(2), "linear");

% Mark the three points on the surface
plot3(init_pt_1(1), init_pt_1(2), init_z_1, "ro", ...
    "MarkerFaceColor", "r", "MarkerSize", 7);
plot3(init_pt_2(1), init_pt_2(2), init_z_2, "mo", ...
    "MarkerFaceColor", "m", "MarkerSize", 7);
plot3(min_pt(1), min_pt(2), min_z, "go", ...
    "MarkerFaceColor", "g", "MarkerSize", 8);

% Create two optimization traces on the surface
n_trace = 120;
t = linspace(0, 1, n_trace);

trace1_x = init_pt_1(1) + (min_pt(1) - init_pt_1(1)) * t;
trace1_y = init_pt_1(2) + (min_pt(2) - init_pt_1(2)) * t;
trace1_z = interp2(x, y, z, trace1_x, trace1_y, "linear");

trace2_x = init_pt_2(1) + (min_pt(1) - init_pt_2(1)) * t;
trace2_y = init_pt_2(2) + (min_pt(2) - init_pt_2(2)) * t;
trace2_z = interp2(x, y, z, trace2_x, trace2_y, "linear");

plot3(trace1_x, trace1_y, trace1_z, "r-", "LineWidth", 2.0);
plot3(trace2_x, trace2_y, trace2_z, "m-", "LineWidth", 2.0);

legend("surface", "init point 1", "init point 2", "minimum", ...
    "trace 1", "trace 2", "Location", "best");
hold off;