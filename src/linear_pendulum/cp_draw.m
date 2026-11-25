function h = cp_draw(ax, P, h, x, th, r)
%CP_DRAW  Draws/updates the cart-pole on a set of axes.
%   h = cp_draw(ax, P)                 creates the graphics and returns handles
%   h = cp_draw(ax, P, h, x, th, r)    updates the pose
wc = 0.16; hc = 0.08;                        % cart size
if nargin < 3 || isempty(h)
    cla(ax); hold(ax, 'on');
    L = P.x_lim;
    plot(ax, [-L-0.1 L+0.1], [-hc/2 -hc/2], 'Color', [0.4 0.4 0.4], 'LineWidth', 3);
    plot(ax, [-L -L], [-0.12 0.05], 'k', 'LineWidth', 4);
    plot(ax, [ L  L], [-0.12 0.05], 'k', 'LineWidth', 4);
    h.cart = patch(ax, 'XData', [-wc wc wc -wc]/2, 'YData', [-hc -hc hc hc]/2, ...
        'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'k');
    h.rod  = plot(ax, [0 0], [0 P.Lp], 'Color', [0.85 0.33 0.10], 'LineWidth', 4);
    h.bob  = plot(ax, 0, P.Lp, 'o', 'MarkerSize', 9, ...
        'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
    h.piv  = plot(ax, 0, 0, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 6);
    h.ref  = plot(ax, 0, -0.11, '^', 'MarkerSize', 9, ...
        'MarkerFaceColor', [0.47 0.67 0.19], 'MarkerEdgeColor', 'none');
    axis(ax, 'equal');
    xlim(ax, [-L-0.25, L+0.25]); ylim(ax, [-P.Lp-0.15, P.Lp+0.15]);
    grid(ax, 'on'); xlabel(ax, 'x [m]');
    hold(ax, 'off');
    if nargin < 4, return; end
end
px = x + P.Lp*sin(th); py = P.Lp*cos(th);
set(h.cart, 'XData', x + [-wc wc wc -wc]/2);
set(h.rod,  'XData', [x px], 'YData', [0 py]);
set(h.bob,  'XData', px, 'YData', py);
set(h.piv,  'XData', x);
set(h.ref,  'XData', r);
end
