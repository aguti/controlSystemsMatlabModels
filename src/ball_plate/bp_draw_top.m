function h = bp_draw_top(ax, P, h, x, y, rx, ry)
%BP_DRAW_TOP  Top (camera) view of the plate: ball, reference and trail.
%   h = bp_draw_top(ax, P)                     creates the graphics
%   h = bp_draw_top(ax, P, h, x, y, rx, ry)    updates (positions in m)
%   This is what the overhead camera sees. In the GUI a click on these axes
%   sets the reference point. Clear the trail with
%   set(h.trail, 'XData', nan, 'YData', nan).
a = P.a;
if nargin < 3 || isempty(h)
    cla(ax); hold(ax, 'on');
    t = linspace(0, 2*pi, 41);
    patch(ax, a*[-1 1 1 -1], a*[-1 -1 1 1], [0.86 0.89 0.93], 'EdgeColor', [0.20 0.45 0.75], ...
        'LineWidth', 2, 'HitTest', 'off');
    for v = -0.10:0.05:0.10
        plot(ax, [v v], [-a a], 'Color', [0.62 0.67 0.75], 'HitTest', 'off');
        plot(ax, [-a a], [v v], 'Color', [0.62 0.67 0.75], 'HitTest', 'off');
    end
    m = P.x_ref_max;
    plot(ax, m*[-1 1 1 -1 -1], m*[-1 -1 1 1 -1], ':', 'Color', [0.47 0.67 0.19], 'HitTest', 'off');
    h.trail = plot(ax, nan, nan, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2, 'HitTest', 'off');
    h.ref  = plot(ax, 0, 0, '+', 'Color', [0.30 0.60 0.10], 'MarkerSize', 14, 'LineWidth', 2, 'HitTest', 'off');
    h.refc = plot(ax, 1.25*P.rb*cos(t), 1.25*P.rb*sin(t), 'Color', [0.30 0.60 0.10], 'LineWidth', 2, 'HitTest', 'off');
    h.ball = patch(ax, P.rb*cos(t), P.rb*sin(t), [0.85 0.15 0.10], 'EdgeColor', 'k', 'HitTest', 'off');
    h.ct = t;
    hold(ax, 'off');
    axis(ax, 'equal'); xlim(ax, (a + 0.01)*[-1 1]); ylim(ax, (a + 0.01)*[-1 1]);
    xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]'); box(ax, 'on');
    if nargin < 4, return; end
end
set(h.ball, 'XData', x + P.rb*cos(h.ct), 'YData', y + P.rb*sin(h.ct));
set(h.ref,  'XData', rx, 'YData', ry);
set(h.refc, 'XData', rx + 1.25*P.rb*cos(h.ct), 'YData', ry + 1.25*P.rb*sin(h.ct));
X = [get(h.trail, 'XData') x]; Y = [get(h.trail, 'YData') y];
n = numel(X); k = max(1, n - 150):n;
set(h.trail, 'XData', X(k), 'YData', Y(k));
end
