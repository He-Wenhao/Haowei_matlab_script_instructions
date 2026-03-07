clear;

N = 100;
x = 1:N;
y = 1:N;
[x, y] = meshgrid(x, y);

z = ((sin(5*x./N)+1).*(cos(15*y./N)-1) + 10*rand(1, N))...
    .*((cos(5*y./N)-1).*(sin(15*x./N)+1) + 10*rand(1, N));

% z = ((sin(2*x./N)+1).*(cos(2*y./N)-1) + 2*rand(1, N))...
%     .*((cos(2*y./N)-1).*(sin(2*x./N)+1) + 2*rand(1, N));



zz = fft2(z);
zzz = zeros(N, N);
n = 2;
zzz(1:n, 1:n) = zz(1:n, 1:n);
z = ifft2(zzz);

z = real(z);
mesh(x, y, z);
set(gcf, 'Color', 'none');
axis off