function bp_animate(res, P, speed)
%BP_ANIMATE  Replays a saved run (struct returned by BallPlate.run):
%   3D scene on the left, top (camera) view on the right.
%   bp_animate(res)            uses res.P
%   bp_animate(res, P, 0.5)    at half speed
if nargin < 2 || isempty(P), P = res.P; end
if nargin < 3, speed = 1; end
fig = figure('Name', 'Ball and plate animation', 'Color', 'w', 'Position', [100 100 1100 500]);
tl = tiledlayout(fig, 1, 5, 'TileSpacing', 'compact');
ax3 = nexttile(tl, [1 3]); axT = nexttile(tl, [1 2]);
h  = bp_draw(ax3, P);
hT = bp_draw_top(axT, P);
ttl = title(tl, '');
fps = 30; t0 = tic; N = numel(res.t);
while ishandle(fig)
    tsim = toc(t0)*speed;
    k = find(res.t >= tsim, 1);
    if isempty(k), k = N; end
    bp_draw(ax3, P, h, res.x(k), res.y(k), res.al(k), res.be(k), res.rx(k), res.ry(k));
    bp_draw_top(axT, P, hT, res.x(k), res.y(k), res.rx(k), res.ry(k));
    set(ttl, 'String', sprintf('t = %.2f s   x = %+.1f cm   y = %+.1f cm   \\alpha = %+.1f°   \\beta = %+.1f°', ...
        res.t(k), res.x_cm(k), res.y_cm(k), res.al_deg(k), res.be_deg(k)));
    drawnow;
    if k == N, break; end
    pause(1/fps);
end
end
