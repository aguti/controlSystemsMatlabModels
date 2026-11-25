function h = rp_draw(ax, P, h, th, al, r)
%RP_DRAW  Draws/updates the rotary pendulum in 3D on a set of axes.
%   h = rp_draw(ax, P)                  creates the graphics and returns handles
%   h = rp_draw(ax, P, h, th, al, r)    updates the pose (angles in rad)
%
%   Scene (metres, z up): motor body below the arm, arm rotating in the
%   horizontal plane z = 0, pendulum hanging from the arm tip, dashed circle
%   swept by the arm tip with the reference marker, and the shadow of the arm
%   and pendulum on the base plate to help perceive depth.
%   Change the viewpoint with view(ax, az, el) or rp_view(ax, 'iso'|'top'|'front'|'side').

zf  = -(P.Lp + 0.025);                % base plate height (below the hanging pendulum)
R   = sqrt(P.Lr^2 + P.Lp^2) + 0.015; % scene radius (furthest reach of the tip)
rr  = P.Lr + 0.016;                   % radius of the reference marker
if nargin < 3 || isempty(h)
    cla(ax); hold(ax, 'on');
    % --- base plate ---
    s = R*0.95;
    patch(ax, 'XData', [-s s s -s], 'YData', [-s -s s s], 'ZData', zf*[1 1 1 1], ...
        'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.70 0.70 0.70], ...
        'AmbientStrength', 1, 'DiffuseStrength', 0, 'SpecularStrength', 0);
    % --- motor body and hub ---
    cyl(ax, 0.028, zf, -0.018, [0.32 0.33 0.36]);
    cyl(ax, 0.011, -0.018, 0, [0.72 0.72 0.75]);
    % --- arm tip circle and angle origin ---
    a = linspace(0, 2*pi, 121);
    plot3(ax, P.Lr*cos(a), P.Lr*sin(a), 0*a, ':', 'Color', [0.55 0.55 0.55]);
    plot3(ax, [0 P.Lr+0.02], [0 0], [0 0], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
    % --- shadows ---
    h.armSh = plot3(ax, [0 P.Lr], [0 0], zf*[1 1] + 1e-4, 'Color', [0.70 0.70 0.70], 'LineWidth', 5);
    h.penSh = plot3(ax, [P.Lr P.Lr], [0 0], zf*[1 1] + 1e-4, 'Color', [0.78 0.70 0.66], 'LineWidth', 3);
    % --- reference marker ---
    h.ref = plot3(ax, rr, 0, 0, 'v', 'MarkerSize', 8, ...
        'MarkerFaceColor', [0.47 0.67 0.19], 'MarkerEdgeColor', 'none');
    % --- arm and pendulum ---
    h.arm = plot3(ax, [0 P.Lr], [0 0], [0 0], 'Color', [0.20 0.45 0.75], 'LineWidth', 7);
    h.piv = plot3(ax, P.Lr, 0, 0, 'o', 'MarkerSize', 6, ...
        'MarkerFaceColor', [0.9 0.9 0.9], 'MarkerEdgeColor', 'k');
    h.pen = plot3(ax, [P.Lr P.Lr], [0 0], [0 P.Lp], 'Color', [0.85 0.33 0.10], 'LineWidth', 4);
    h.bob = plot3(ax, P.Lr, 0, P.Lp, 'o', 'MarkerSize', 8, ...
        'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
    hold(ax, 'off');
    axis(ax, 'equal');
    xlim(ax, [-R R]); ylim(ax, [-R R]); zlim(ax, [zf, P.Lp + 0.02]);
    grid(ax, 'on'); box(ax, 'off');
    xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]'); zlabel(ax, 'z [m]');
    ax.Clipping = 'off';
    view(ax, 62, 20);
    camlight(ax, 'headlight'); lighting(ax, 'gouraud');
    if nargin < 4, return; end
end
% --- update pose ---
rd = [cos(th); sin(th); 0];           % radial direction (along the arm)
td = [-sin(th); cos(th); 0];          % tangential direction (+theta)
tip = P.Lr*rd;
pe  = tip + P.Lp*(sin(al)*td + [0; 0; cos(al)]);
set(h.arm,   'XData', [0 tip(1)], 'YData', [0 tip(2)], 'ZData', [0 0]);
set(h.piv,   'XData', tip(1), 'YData', tip(2), 'ZData', 0);
set(h.pen,   'XData', [tip(1) pe(1)], 'YData', [tip(2) pe(2)], 'ZData', [0 pe(3)]);
set(h.bob,   'XData', pe(1), 'YData', pe(2), 'ZData', pe(3));
set(h.armSh, 'XData', [0 tip(1)], 'YData', [0 tip(2)]);
set(h.penSh, 'XData', [tip(1) pe(1)], 'YData', [tip(2) pe(2)]);
set(h.ref,   'XData', rr*cos(r), 'YData', rr*sin(r));
end

function cyl(ax, rad, z0, z1, col)
[X, Y, Z] = cylinder(rad, 32);
surf(ax, X, Y, z0 + (z1 - z0)*Z, 'FaceColor', col, 'EdgeColor', 'none');
t = linspace(0, 2*pi, 33);
patch(ax, rad*cos(t), rad*sin(t), z1 + 0*t, col, 'EdgeColor', 'none');
end
