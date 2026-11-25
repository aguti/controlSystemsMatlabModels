function cp_animate(res, P, speed)
%CP_ANIMATE  Replays a saved run (struct returned by CartPole.run).
%   cp_animate(res)            uses res.P
%   cp_animate(res, P, 0.5)    at half speed
if nargin < 2 || isempty(P), P = res.P; end
if nargin < 3, speed = 1; end
fig = figure('Name', 'Cart-pole animation', 'Color', 'w');
ax = axes(fig);
h = cp_draw(ax, P);
ttl = title(ax, '');
fps = 30; t0 = tic; k = 1; N = numel(res.t);
while ishandle(fig) && k <= N
    tsim = toc(t0)*speed;
    k = find(res.t >= tsim, 1);
    if isempty(k), k = N; end
    cp_draw(ax, P, h, res.x(k), res.th(k), res.r(k));
    set(ttl, 'String', sprintf('t = %.2f s   x = %+.3f m   \\theta = %+.1f°   F = %+.1f N', ...
        res.t(k), res.x(k), res.th_deg(k), res.Fact(k)));
    drawnow;
    if k == N, break; end
    pause(1/fps);
end
end
