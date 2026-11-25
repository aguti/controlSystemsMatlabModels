function h = bb_draw(ax, P, h, x, al, r)
%BB_DRAW  Draws/updates the ball and beam in 3D on a set of axes.
%   h = bb_draw(ax, P)                 creates the graphics and returns handles
%   h = bb_draw(ax, P, h, x, al, r)    updates the pose (x, r in m; al in rad)
%
%   Scene (metres, z up): base plate, pedestal and geared motor behind the
%   beam, beam pivoted at its centre (height H) with a centimetre scale,
%   end stops, the ball rolling in the groove (two-tone so its spin is
%   visible), the reference marker (green triangle) and the ball shadow.
%   Change the viewpoint with view(ax, az, el) or bb_view(ax, 'iso'|'front'|'top'|'side').

H  = 0.13;                    % pivot height above the base
wb = 0.03; tb = 0.012;        % beam width (y) and thickness (z)
zt = tb/2;                    % top surface of the beam (beam frame)
zc = zt + 0.8*P.rb;           % ball centre (sits in the groove)
Lh = P.L/2;
if nargin < 3 || isempty(h)
    cla(ax); hold(ax, 'on');
    % --- base plate ---
    bx = Lh + 0.04; by = 0.09;
    patch(ax, 'XData', [-bx bx bx -bx], 'YData', [-by -by by by], 'ZData', [0 0 0 0], ...
        'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.70 0.70 0.70], ...
        'AmbientStrength', 1, 'DiffuseStrength', 0, 'SpecularStrength', 0);
    % --- pedestal, gearbox + motor and shaft (behind the beam, y > 0) ---
    box3(ax, [-0.02 0.02], [0.035 0.075], [0 H-0.03], [0.55 0.56 0.60]);
    box3(ax, [-0.03 0.03], [0.030 0.080], [H-0.03 H+0.03], [0.32 0.33 0.36]);
    cylY(ax, 0.022, 0.080, 0.13, H, [0.25 0.26 0.29]);
    cylY(ax, 0.006, 0.000, 0.030, H, [0.72 0.72 0.75]);
    % --- moving beam (hgtransform) ---
    h.tBeam = hgtransform('Parent', ax);
    box3(h.tBeam, [-Lh Lh], [-wb/2 wb/2], [-tb/2 zt], [0.20 0.45 0.75]);
    line('Parent', h.tBeam, 'XData', [-Lh Lh], 'YData', [-0.006 -0.006], 'ZData', [zt zt]+1e-4, 'Color', [0.10 0.25 0.45], 'LineWidth', 1);
    line('Parent', h.tBeam, 'XData', [-Lh Lh], 'YData', [0.006 0.006], 'ZData', [zt zt]+1e-4, 'Color', [0.10 0.25 0.45], 'LineWidth', 1);
    for xs = -0.20:0.05:0.20                         % scale every 5 cm on the front face
        ht = 0.004 + 0.004*(abs(xs) < 1e-9);
        line('Parent', h.tBeam, 'XData', [xs xs], 'YData', -wb/2*[1 1] - 1e-4, 'ZData', [zt zt-ht], 'Color', 'w', 'LineWidth', 1);
    end
    box3(h.tBeam, [-Lh-0.008 -Lh], [-wb/2 wb/2], [-tb/2 zt+0.022], [0.30 0.30 0.32]);
    box3(h.tBeam, [Lh Lh+0.008],   [-wb/2 wb/2], [-tb/2 zt+0.022], [0.30 0.30 0.32]);
    % --- reference marker (beam frame) ---
    h.tRef = hgtransform('Parent', h.tBeam);
    patch('Parent', h.tRef, 'XData', [-0.009 0.009 0], 'YData', [0 0 0], ...
        'ZData', zt + 2*P.rb + 0.012 + [0.014 0.014 0], ...
        'FaceColor', [0.47 0.67 0.19], 'EdgeColor', 'none');
    % --- ball (two-tone sphere) ---
    h.tBall = hgtransform('Parent', h.tBeam);
    [X, Y, Z] = sphere(32);
    C = mod(floor((atan2(Z, X) + pi)/(pi/2)), 2);    % four sectors around the spin axis (y)
    C = repmat(C, 1, 1, 3).*reshape([0.80 0.10 0.08], 1, 1, 3) ...
      + repmat(1 - C, 1, 1, 3).*reshape([0.97 0.90 0.82], 1, 1, 3);
    surface('Parent', h.tBall, 'XData', P.rb*X, 'YData', P.rb*Y, 'ZData', P.rb*Z, 'CData', C, 'FaceColor', 'interp', 'EdgeColor', 'none', 'FaceLighting', 'gouraud');
    % --- ball shadow on the base ---
    a = linspace(0, 2*pi, 25);
    h.shadow = patch(ax, 'XData', P.rb*cos(a), 'YData', P.rb*sin(a), 'ZData', 2e-4 + 0*a, ...
        'FaceColor', [0.62 0.62 0.62], 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    h.shX = P.rb*cos(a); h.shY = P.rb*sin(a);
    hold(ax, 'off');
    axis(ax, 'equal');
    xlim(ax, [-bx bx]); ylim(ax, [-by by]); zlim(ax, [0 H + 0.08]);
    grid(ax, 'on'); box(ax, 'off');
    xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]'); zlabel(ax, 'z [m]');
    ax.Clipping = 'off';
    bb_view(ax, 'iso');
    camlight(ax, 'headlight'); lighting(ax, 'gouraud');
    h.H = H; h.zc = zc;
    if nargin < 4, return; end
end
% --- update pose ---
Rb = makehgtform('translate', [0 0 h.H], 'yrotate', -al);
set(h.tBeam, 'Matrix', Rb);
set(h.tBall, 'Matrix', makehgtform('translate', [x 0 h.zc], 'yrotate', x/P.rb));
set(h.tRef,  'Matrix', makehgtform('translate', [r 0 0]));
pw = Rb*[x; 0; h.zc; 1];                         % ball centre in world coordinates
set(h.shadow, 'XData', pw(1) + h.shX, 'YData', pw(2) + h.shY);
end

function box3(parent, xr, yr, zr, col)
%BOX3  Axis-aligned box as a patch with 6 faces.
[X, Y, Z] = ndgrid(xr, yr, zr);
V = [X(:) Y(:) Z(:)];
F = [1 2 4 3; 5 6 8 7; 1 2 6 5; 3 4 8 7; 1 3 7 5; 2 4 8 6];
patch('Parent', parent, 'Vertices', V, 'Faces', F, 'FaceColor', col, 'EdgeColor', 'none', ...
    'FaceLighting', 'flat');
end

function cylY(ax, rad, y0, y1, zc, col)
%CYLY  Cylinder along y at height zc.
[X, Z, Y] = cylinder(rad, 32);
surf(ax, X, y0 + (y1 - y0)*Y, zc + Z, 'FaceColor', col, 'EdgeColor', 'none');
t = linspace(0, 2*pi, 33);
patch(ax, rad*cos(t), y0 + 0*t, zc + rad*sin(t), col, 'EdgeColor', 'none');
end
