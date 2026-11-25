function bb_animate(res, P, speed)
%BB_ANIMATE  Replays a saved run (struct returned by BallBeam.run) in 3D.
%   bb_animate(res)            uses res.P
%   bb_animate(res, P, 0.5)    at half speed
if nargin < 2 || isempty(P), P = res.P; end
if nargin < 3, speed = 1; end
fig = figure('Name', 'Ball and beam animation', 'Color', 'w');
ax = axes(fig);
h = bb_draw(ax, P);
ttl = title(ax, '');
fps = 30; t0 = tic; N = numel(res.t);
while ishandle(fig)
    tsim = toc(t0)*speed;
    k = find(res.t >= tsim, 1);
    if isempty(k), k = N; end
    bb_draw(ax, P, h, res.x(k), res.al(k), res.r(k));
    set(ttl, 'String', sprintf('t = %.2f s   x = %+.1f cm   \\alpha = %+.1f°   V = %+.1f V', ...
        res.t(k), res.x_cm(k), res.al_deg(k), res.Vact(k)));
    drawnow;
    if k == N, break; end
    pause(1/fps);
end
end
