function h = bp_draw(ax, P, h, x, y, al, be, rx, ry)
%BP_DRAW  Draws/updates the ball and plate in 3D on a set of axes.
%   h = bp_draw(ax, P)                              creates the graphics
%   h = bp_draw(ax, P, h, x, y, al, be, rx, ry)     updates the pose
%   (positions in m, angles in rad)
%
%   Scene (metres, z up): base, central post, two-axis gimbal. Motor A
%   (fixed, on the -y side) tilts the outer frame by alpha about y; motor B
%   rides on the outer frame (+x side) and tilts the plate by beta about x.
%   The plate has a 5 cm grid and a rim; the ball is two-tone so that its
%   rolling is visible, leaves a short trail and casts a shadow on the base.
%   The green ring is the reference. Clear the trail with
%   set(h.trail, 'XData', nan, 'YData', nan, 'ZData', nan).
%   Change the viewpoint with view(ax, az, el) or bp_view(ax, 'iso'|'top'|'front'|'side').

H  = 0.12;                    % gimbal centre height
a  = P.a;
tp = 0.006;                   % plate thickness
zt = tp/2;                    % plate top surface (plate frame)
zc = zt + P.rb;               % ball centre
if nargin < 3 || isempty(h)
    cla(ax); hold(ax, 'on');
    % --- base, post and motor A (fixed) ---
    bs = a + 0.09;
    patch(ax, 'XData', bs*[-1 1 1 -1], 'YData', bs*[-1 -1 1 1], 'ZData', [0 0 0 0], ...
        'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.70 0.70 0.70], ...
        'AmbientStrength', 1, 'DiffuseStrength', 0, 'SpecularStrength', 0);
    box3(ax, [-0.015 0.015], [-0.015 0.015], [0 H-0.02], [0.55 0.56 0.60]);
    box3(ax, [-0.012 0.012], [-0.012 0.012], [H-0.02 H-0.004], [0.40 0.41 0.45]);
    box3(ax, [-0.012 0.012], [-a-0.075 -a-0.045], [0 H-0.022], [0.55 0.56 0.60]);
    cyl(ax, 'y', 0.022, -a-0.085, -a-0.035, [0 H], [0.25 0.26 0.29]);
    cyl(ax, 'y', 0.005, -a-0.035, -a-0.020, [0 H], [0.72 0.72 0.75]);
    % --- outer frame (alpha) with motor B ---
    h.tA = hgtransform('Parent', ax);
    fo = a + 0.020; fi = a + 0.010; ft = [-0.004 0.004];
    box3(h.tA, [-fo fo], [-fo -fi], ft, [0.30 0.30 0.33]);
    box3(h.tA, [-fo fo], [fi fo],   ft, [0.30 0.30 0.33]);
    box3(h.tA, [-fo -fi], [-fi fi], ft, [0.30 0.30 0.33]);
    box3(h.tA, [fi fo],   [-fi fi], ft, [0.30 0.30 0.33]);
    cyl(h.tA, 'x', 0.018, a+0.030, a+0.075, [0 0], [0.25 0.26 0.29]);
    cyl(h.tA, 'x', 0.005, a+0.020, a+0.030, [0 0], [0.72 0.72 0.75]);
    % --- plate (beta, inside the outer frame) ---
    h.tB = hgtransform('Parent', h.tA);
    box3(h.tB, [-a a], [-a a], [-tp/2 zt], [0.86 0.89 0.93], ...
        'AmbientStrength', 0.9, 'DiffuseStrength', 0.25, 'SpecularStrength', 0);
    g = -0.10:0.05:0.10;
    for v = g
        lw = 0.5 + 0.7*(abs(v) < 1e-9);
        line('Parent', h.tB, 'XData', [v v], 'YData', [-a a], 'ZData', [zt zt] + 2e-4, ...
            'Color', [0.62 0.67 0.75], 'LineWidth', lw);
        line('Parent', h.tB, 'XData', [-a a], 'YData', [v v], 'ZData', [zt zt] + 2e-4, ...
            'Color', [0.62 0.67 0.75], 'LineWidth', lw);
    end
    rw = 0.004; rh = zt + 0.012;                    % rim
    box3(h.tB, [-a a], [-a -a+rw], [zt rh], [0.20 0.45 0.75]);
    box3(h.tB, [-a a], [a-rw a],   [zt rh], [0.20 0.45 0.75]);
    box3(h.tB, [-a -a+rw], [-a a], [zt rh], [0.20 0.45 0.75]);
    box3(h.tB, [a-rw a],   [-a a], [zt rh], [0.20 0.45 0.75]);
    % --- trail and reference ---
    h.trail = line('Parent', h.tB, 'XData', nan, 'YData', nan, 'ZData', nan, ...
        'Color', [0.85 0.33 0.10], 'LineWidth', 1.2);
    h.tRef = hgtransform('Parent', h.tB);
    t = linspace(0, 2*pi, 41);
    line('Parent', h.tRef, 'XData', 1.25*P.rb*cos(t), 'YData', 1.25*P.rb*sin(t), ...
        'ZData', zt + 4e-4 + 0*t, 'Color', [0.30 0.60 0.10], 'LineWidth', 2.5);
    line('Parent', h.tRef, 'XData', [-1 1 nan 0 0]*0.6*P.rb, 'YData', [0 0 nan -1 1]*0.6*P.rb, ...
        'ZData', zt + 4e-4 + [0 0 nan 0 0], 'Color', [0.30 0.60 0.10], 'LineWidth', 1.5);
    % --- ball (two-tone sphere) ---
    h.tBall = hgtransform('Parent', h.tB);
    [X, Y, Z] = sphere(32);
    C = xor(X > 0, Y > 0) ~= (Z > 0);               % octants
    C = repmat(C, 1, 1, 3).*reshape([0.80 0.10 0.08], 1, 1, 3) ...
      + repmat(1 - C, 1, 1, 3).*reshape([0.97 0.90 0.82], 1, 1, 3);
    surface('Parent', h.tBall, 'XData', P.rb*X, 'YData', P.rb*Y, 'ZData', P.rb*Z, ...
        'CData', C, 'FaceColor', 'interp', 'EdgeColor', 'none', 'FaceLighting', 'gouraud');
    % --- ball shadow on the base ---
    h.shX = P.rb*cos(t); h.shY = P.rb*sin(t);
    h.shadow = patch(ax, 'XData', h.shX, 'YData', h.shY, 'ZData', 2e-4 + 0*t, ...
        'FaceColor', [0.62 0.62 0.62], 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    hold(ax, 'off');
    axis(ax, 'equal');
    xlim(ax, [-bs bs]); ylim(ax, [-bs bs]); zlim(ax, [0 H + 0.06]);
    grid(ax, 'on'); box(ax, 'off');
    xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]'); zlabel(ax, 'z [m]');
    ax.Clipping = 'off';
    bp_view(ax, 'iso');
    camlight(ax, 'headlight'); lighting(ax, 'gouraud');
    h.H = H; h.zc = zc; h.zt = zt;
    h.tBall.UserData = struct('R', eye(3), 'p', [nan nan]);
    if nargin < 4, return; end
end
% --- update pose ---
MA = makehgtform('translate', [0 0 h.H], 'yrotate', -al);
MB = makehgtform('xrotate', be);
set(h.tA, 'Matrix', MA);
set(h.tB, 'Matrix', MB);
set(h.tRef, 'Matrix', makehgtform('translate', [rx ry 0]));
% ball spin: rolling without slipping, accumulated orientation
st = h.tBall.UserData;
d  = [x y] - st.p;
if all(isfinite(d)) && norm(d) > 1e-9 && norm(d) < 0.05
    ax_ = [-d(2) d(1) 0]/norm(d);
    st.R = axang(ax_, norm(d)/P.rb)*st.R;
end
st.p = [x y];
h.tBall.UserData = st;
set(h.tBall, 'Matrix', makehgtform('translate', [x y h.zc])*blkdiag(st.R, 1));
% trail (last ~3 s at the GUI rate)
X = [get(h.trail, 'XData') x]; Y = [get(h.trail, 'YData') y];
n = numel(X); k = max(1, n - 90):n;
set(h.trail, 'XData', X(k), 'YData', Y(k), 'ZData', h.zt + 3e-4 + 0*k);
pw = MA*MB*[x; y; h.zc; 1];
set(h.shadow, 'XData', pw(1) + h.shX, 'YData', pw(2) + h.shY);
end

function R = axang(u, th)
%AXANG  Rotation matrix about the unit axis u by angle th (Rodrigues).
K = [0 -u(3) u(2); u(3) 0 -u(1); -u(2) u(1) 0];
R = eye(3) + sin(th)*K + (1 - cos(th))*K*K;
end

function box3(parent, xr, yr, zr, col, varargin)
%BOX3  Axis-aligned box as a patch with 6 faces.
[X, Y, Z] = ndgrid(xr, yr, zr);
V = [X(:) Y(:) Z(:)];
F = [1 2 4 3; 5 6 8 7; 1 2 6 5; 3 4 8 7; 1 3 7 5; 2 4 8 6];
patch('Parent', parent, 'Vertices', V, 'Faces', F, 'FaceColor', col, 'EdgeColor', 'none', ...
    'FaceLighting', 'flat', varargin{:});
end

function cyl(parent, axisName, rad, s0, s1, c, col)
%CYL  Cylinder along x or y from s0 to s1; c = the other two coordinates [y|x, z].
[A, B, S] = cylinder(rad, 32);
S = s0 + (s1 - s0)*S;
t = linspace(0, 2*pi, 33);
if axisName == 'x'
    surface('Parent', parent, 'XData', S, 'YData', c(1) + A, 'ZData', c(2) + B, ...
        'FaceColor', col, 'EdgeColor', 'none');
    patch('Parent', parent, 'XData', s1 + 0*t, 'YData', c(1) + rad*cos(t), ...
        'ZData', c(2) + rad*sin(t), 'FaceColor', col, 'EdgeColor', 'none');
else
    surface('Parent', parent, 'XData', c(1) + A, 'YData', S, 'ZData', c(2) + B, ...
        'FaceColor', col, 'EdgeColor', 'none');
    patch('Parent', parent, 'XData', c(1) + rad*cos(t), 'YData', s0 + 0*t, ...
        'ZData', c(2) + rad*sin(t), 'FaceColor', col, 'EdgeColor', 'none');
end
end
