function rp_animate(res, P, speed)
%RP_ANIMATE  Replays a saved run (struct returned by RotaryPendulum.run) in 3D.
%   rp_animate(res)            uses res.P
%   rp_animate(res, P, 0.5)    at half speed
if nargin < 2 || isempty(P), P = res.P; end
if nargin < 3, speed = 1; end
fig = figure('Name', 'Rotary pendulum animation', 'Color', 'w');
ax = axes(fig);
h = rp_draw(ax, P);
ttl = title(ax, '');
fps = 30; t0 = tic; k = 1; N = numel(res.t);
while ishandle(fig) && k <= N
    tsim = toc(t0)*speed;
    k = find(res.t >= tsim, 1);
    if isempty(k), k = N; end
    rp_draw(ax, P, h, res.th(k), res.al(k), res.r(k));
    set(ttl, 'String', sprintf('t = %.2f s   \\theta = %+.1f°   \\alpha = %+.1f°   V = %+.1f V', ...
        res.t(k), res.th_deg(k), res.al_deg(k), res.Vact(k)));
    drawnow;
    if k == N, break; end
    pause(1/fps);
end
end
