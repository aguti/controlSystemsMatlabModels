function generate_data()
%GENERATE_DATA  Generates every data file and image used by the ball and
%   beam manual, running the Simulink model (ballbeam_sim.slx).
%   Run from this folder:  generate_data
%   Output: *.dat (pgfplots tables), num.txt (values quoted in the text),
%           frames.png and gui.png (figures).

D = fileparts(mfilename('fullpath'));
src = fullfile(D, '..', '..', '..', '..', 'src', 'ball_beam');
addpath(src);
old = cd(src); cleanup = onCleanup(@() cd(old));
set(0, 'DefaultFigureVisible', 'off');

bb_build_model();
bb = BallBeam();
P = bb.P;
num = fopen(fullfile(D, 'num.txt'), 'w');
pr = @(varargin) fprintf(num, varargin{:});

%% ---------- Linear analysis ----------
lin = bb.Lin;
pr('K = %s\n', mat2str(P.K, 4));
pr('A = %s\nB = %s\n', mat2str(lin.A, 4), mat2str(lin.B, 4));
pr('poles_OL = %s\npoles_CL = %s\n', mat2str(lin.poles_OL.', 4), mat2str(lin.poles_CL.', 4));
pr('Jb = %.4g  mb = %.4g  J = %.4g  Jbeam = %.4g  Jrot = %.4g\n', P.Jb, P.mb, P.J, ...
    P.mbeam*P.L^2/12, P.eta_g*P.Kg^2*P.Jm);
pr('kv = %.4g  beq = %.4g  b_emf = %.4g  x_max = %.4g\n', P.kv, P.beq, P.kv*P.Kg*P.km, P.x_max);
pr('ball accel per rad = %.4g (5/7 g)\n', P.m*P.g/P.mb);
pr('stall torque = %.4g N m, max weight torque = %.4g N m, V to hold ball at end = %.3g V\n', ...
    P.kv*P.Vmax, P.m*P.g*P.x_max, P.m*P.g*P.x_max/P.kv);
for o = 1:2
    [z, p, k] = zpkLocal(lin.A, lin.B, lin.C(o,:));
    pr('zpk_y%d: zeros=%s  poles=%s  k=%.4g\n', o, mat2str(z.', 4), mat2str(p.', 4), k);
end
Co = [lin.B lin.A*lin.B lin.A^2*lin.B lin.A^3*lin.B];
pr('rank_ctrb = %d  cond = %.3g\n', rank(Co), cond(Co));
pr('rank_obs: x only %d, alpha only %d\n', rank(obsvLocal(lin.A, lin.C(1,:))), rank(obsvLocal(lin.A, lin.C(2,:))));
% Inner loop (PD on alpha, ball weight neglected) and cascade on the linear model
Kin = [0 0 P.Kp_a P.Kd_a];
pr('poles_inner = %s\n', mat2str(eig(lin.A - lin.B*Kin).', 4));
Kc  = [-P.Kp_a*P.Kp_x, -P.Kp_a*P.Kd_x, P.Kp_a, P.Kd_a];   % cascade as a state feedback (no I, no ff)
pr('poles_cascade_PD = %s\n', mat2str(eig(lin.A - lin.B*Kc).', 4));

f = logspace(-1, 2, 300); w = 2*pi*f; nm = {'x', 'al'};
for o = 1:2
    H = arrayfun(@(wk) lin.C(o,:)*((1i*wk*eye(4) - lin.A)\lin.B), w);
    writeDat(fullfile(D, sprintf('bode_%s.dat', nm{o})), 'f mag ph', ...
        [f(:) 20*log10(abs(H(:))) rad2deg(unwrap(angle(H(:))))]);
end

%% ---------- Simulations ----------
st = @(t0, A, T) deal([0 t0 t0+1e-4 T]', [0 0 A A]');
bb.clearSignals(); bb.setRef('const', 0); bb.enable(true); bb.setVoltage(0);

% Open loop: beam held level by the motor? No: free ball on a beam at -2 deg (mode beam)
bb.setMode('beam'); bb.setBeamAngle(deg2rad(-2)); bb.setInitialState([0 0 0 0]);
res = bb.run(2); save_(D, 'beam_tilt', res);
k = find(abs(res.x) >= P.x_max - 1e-3, 1);
pr('beam_tilt -2deg: reaches stop at %.3f s (theory %.3f s), final al %.2f deg\n', res.t(k), ...
    sqrt(2*P.x_max/(P.m*P.g/P.mb*sin(deg2rad(2)))), res.al_deg(end));
bb.setBeamAngle(0);

% Inner loop step with a (nearly) massless ball
bb.setParam('m', 1e-5); bb.setBeamAngle(deg2rad(5)); bb.setInitialState([0 0 0 0]);
res = bb.run(1); save_(D, 'inner_step', res);
pr('inner step 5deg: final %.3f deg, overshoot %.1f %%, t95 %.3f s\n', res.al_deg(end), ...
    100*(max(res.al_deg)/5 - 1), res.t(find(res.al_deg >= 4.75, 1)));
bb.setParam('m', P.m); bb.setBeamAngle(0);

% LQR from x0 = 10 cm
bb.setMode('lqr'); bb.setInitialState([0.10 0 0 0]);
res = bb.run(5); save_(D, 'lqr_ic', res);
pr('lqr_ic: settle5mm %.2f, Vmax %.2f, min al %.2f max al %.2f, undershoot %.2f cm\n', settle(res.t, res.x, 5e-3), ...
    max(abs(res.Vact)), min(res.al_deg), max(res.al_deg), 100*min(res.x));

% Step 10 cm, LQR and cascade, with the default rate limiter
[t, r] = st(1, 0.10, 6);
for m = {'lqr', 'cascade'}
    bb.setMode(m{1}); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
    res = bb.run(6); save_(D, [m{1} '_step'], res);
    pr('%s_step: settle5mm %.2f s after step, overshoot %.1f %%, final %.2f cm, Vmax %.2f, max|al| %.2f\n', m{1}, ...
        settle(res.t, res.x - 0.10, 5e-3) - 1, 100*(max(res.x)/0.10 - 1), 100*res.x(end), max(abs(res.Vact)), max(abs(res.al_deg)));
end
% Without rate limiter
bb.setParamRaw('ref_rate', 1e6);
for m = {'lqr', 'cascade'}
    bb.setMode(m{1}); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
    res = bb.run(6);
    pr('%s_step no ratelim: settle5mm %.2f, overshoot %.1f %%, Vmax %.2f, max|al| %.2f\n', m{1}, ...
        settle(res.t, res.x - 0.10, 5e-3) - 1, 100*(max(res.x)/0.10 - 1), max(abs(res.Vact)), max(abs(res.al_deg)));
end
bb.setParamRaw('ref_rate', P.ref_rate);

% Weight feedforward (cascade without integral action)
bb.setMode('cascade');
for ff = [1 0]
    bb.setParams(struct('ff_on', ff, 'Ki_x', 0)); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
    res = bb.run(6); save_(D, sprintf('ff_%d', ff), res);
    pr('cascade Ki=0 ff=%d: final x %.2f cm, final al %.3f deg, final V %.3f\n', ff, 100*res.x(end), res.al_deg(end), res.Vact(end));
end
bb.setParams(struct('ff_on', 1, 'Ki_x', P.Ki_x));
% Weight torque vs. static error estimate: alpha_ss = Kp_x e, V = Kp_a(alr - al) ...
pr('ff static: m g r / kv at r = 10 cm = %.3f V\n', P.m*P.g*0.10/P.kv);
% LQR without feedforward (integrator removes the error slowly)
bb.setMode('lqr'); bb.setParam('ff_on', 0); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
res = bb.run(10); save_(D, 'lqr_noff', res);
pr('lqr ff=0: x at 3 s %.2f cm, final %.2f cm, settle5mm %.2f\n', 100*res.x(find(res.t >= 3, 1)), 100*res.x(end), settle(res.t, res.x - 0.10, 5e-3) - 1);
bb.setParam('ff_on', 1);

% Tap on the ball
bb.clearSignals(); bb.setRef('const', 0);
tp = [0 1 1+1e-4 1.05 1.05+1e-4 4]'; fp = [0 0 0.2 0.2 0 0]';
for m = {'lqr', 'cascade'}
    bb.setMode(m{1}); bb.setInitialState([0 0 0 0]); bb.setDisturbanceSignal(tp, fp);
    res = bb.run(4); save_(D, [m{1} '_tap'], res);
    pr('%s_tap: max|x| %.2f cm, settle2mm %.2f s after tap, Vmax %.2f\n', m{1}, 100*max(abs(res.x)), ...
        settle(res.t, res.x, 2e-3) - 1, max(abs(res.Vact)));
end
bb.clearSignals();

% Q_x and R sweeps (LQR from x0 = 10 cm)
bb.setMode('lqr'); bb.setRef('const', 0);
for q = [200 1000 5000]
    bb.setParam('Q', diag([q P.Q(2,2) P.Q(3,3) P.Q(4,4) P.Q(5,5)])); bb.setInitialState([0.10 0 0 0]);
    res = bb.run(4); save_(D, sprintf('qsweep_%d', q), res);
    pr('qsweep Qx=%d: K %s settle %.2f Vmax %.2f max|al| %.2f\n', q, mat2str(bb.P.K, 3), settle(res.t, res.x, 5e-3), ...
        max(abs(res.Vact)), max(abs(res.al_deg)));
end
bb.setParam('Q', P.Q);
for R = [0.1 10]
    bb.setParam('R', R); bb.setInitialState([0.10 0 0 0]);
    res = bb.run(4); save_(D, sprintf('rsweep_%g', R), res);
    pr('rsweep %g: K %s settle %.2f Vmax %.2f\n', R, mat2str(bb.P.K, 3), settle(res.t, res.x, 5e-3), max(abs(res.Vact)));
end
bb.setParam('R', P.R);

% Robustness: ball mass, nominal gains
[t, r] = st(1, 0.10, 6);
for m = [0.03 0.134 0.268]
    bb.setParam('m', m); bb.setParamRaw('K', P.K);
    for c = {'lqr', 'cascade'}
        bb.setMode(c{1}); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
        res = bb.run(6);
        if strcmp(c{1}, 'lqr'), save_(D, sprintf('msweep_%g', m), res); end
        pr('msweep %s m=%g: settle %.2f overshoot %.1f %% final %.2f cm\n', c{1}, m, settle(res.t, res.x - 0.10, 5e-3) - 1, ...
            100*(max(res.x)/0.10 - 1), 100*res.x(end));
    end
end
bb.setParam('m', P.m); bb.clearSignals();

% Sine tracking
for c = {'lqr', 'cascade'}
    bb.setMode(c{1});
    for fr = [0.1 0.25 0.5]
        bb.setInitialState([0 0 0 0]); bb.setRef('sine', 0, 0.10, fr);
        res = bb.run(5/fr + 2); kk = res.t > 2/fr; E = exp(-1i*2*pi*fr*res.t(kk));
        g = sum(res.x(kk).*E)/sum(res.r(kk).*E);
        pr('sine %s %g Hz: gain %.3f lag %.1f\n', c{1}, fr, abs(g), -rad2deg(angle(g)));
        if fr == 0.25 && strcmp(c{1}, 'lqr'), save_(D, 'sine_0.25', res); end
    end
end
bb.setRef('const', 0);

% Sensor noise
bb.setMode('lqr'); bb.setParam('noise_on', 1); bb.setInitialState([0.10 0 0 0]);
res = bb.run(5); save_(D, 'lqr_noise', res); kk = res.t > 2.5;
pr('noise: x std %.3f mm, al std %.3f deg, V std %.3f\n', 1e3*std(res.x(kk)), std(res.al_deg(kk)), std(res.Vact(kk)));
bb.setParam('noise_on', 0);
res = bb.run(5); kk = res.t > 2.5;
pr('quantization only: x std %.3f mm, V std %.3f\n', 1e3*std(res.x(kk)), std(res.Vact(kk)));

% Velocity estimation from the quantized ball position
Ts = P.Ts; t = (0:Ts:1)'; xr = 0.1*sin(2*pi*1*t); xq = round(xr/P.res_x)*P.res_x;
raw = [0; diff(xq)/Ts]; a = exp(-Ts/P.tau_x); v = zeros(size(t));
for k = 2:numel(t), v(k) = a*v(k-1) + (1 - a)*(xq(k) - xq(k-1))/Ts; end
writeDat(fullfile(D, 'velest.dat'), 't true raw filt', [t 0.1*2*pi*cos(2*pi*t) raw v]);
pr('velest: quantum velocity %.4g m/s, raw std err %.4g, filt std err %.4g\n', P.res_x/Ts, ...
    std(raw(10:end) - 0.1*2*pi*cos(2*pi*t(10:end))), std(v(30:end) - 0.1*2*pi*cos(2*pi*t(30:end))));

%% ---------- Images ----------
bb.setMode('lqr'); bb.setInitialState([0 0 0 0]); [t, r] = st(0.2, 0.12, 4); bb.setRefSignal(t, r);
mv = bb.run(4); bb.clearSignals();
fig = figure('Color', 'w', 'Position', [0 0 1600 380]);
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'none', 'Padding', 'compact');
ts = [0 0.5 0.8 2.5];
for i = 1:numel(ts)
    ax = nexttile(tl); h = bb_draw(ax, P); j = find(mv.t >= ts(i), 1);
    bb_draw(ax, P, h, mv.x(j), mv.al(j), mv.r(j));
    ax.XTickLabel = {}; ax.YTickLabel = {}; ax.ZTickLabel = {};
    xlabel(ax, ''); ylabel(ax, ''); zlabel(ax, '');
    title(ax, sprintf('t = %.2f s\nx = %+.1f cm   \\alpha = %+.1f°', mv.t(j), mv.x_cm(j), mv.al_deg(j)), ...
        'FontWeight', 'normal', 'FontSize', 13);
end
exportgraphics(fig, fullfile(D, 'frames.png'), 'Resolution', 150);
close(fig);
pr('frames at t = %s (LQR, step to 12 cm at 0.2 s)\n', mat2str(ts));

set(0, 'DefaultFigureVisible', 'on');
bb = BallBeam(); bb_gui(bb);
f = findall(groot, 'Type', 'figure', 'Name', 'Ball and beam — live Simulink');
c = findall(f, 'Type', 'uidropdown');
dr = c(arrayfun(@(x) any(strcmp(x.Items, 'Sine')), c)); dr.Value = 1; dr.ValueChangedFcn(dr, []);
b = findall(f, 'Type', 'uibutton'); bs = b(strcmp({b.Text}, '▶ Start')); bs.ButtonPushedFcn(bs, []);
w0 = tic; while bb.LastTime < 7.5 && toc(w0) < 60, pause(0.1); end
exportapp(f, fullfile(D, 'gui.png'));
bb.stop(); pause(0.5); rl = bb.lastResult(); delete(f);
pr('gui run: t end %.2f, CmdRef %s, max|x| %.2f cm\n', rl.t(end), mat2str(bb.CmdRef, 3), max(abs(rl.x_cm)));
fclose(num);
fprintf('Manual data written to %s\n', D);
end

%% ======================= helpers =======================
function save_(D, name, res)
k = 1:5:numel(res.t);                                % 5 ms resolution
writeDat(fullfile(D, [name '.dat']), 't x al V r alr', ...
    [res.t(k) res.x_cm(k) res.al_deg(k) res.Vact(k) res.r_cm(k) res.alr_deg(k)]);
end

function writeDat(file, header, M)
fid = fopen(file, 'w');
fprintf(fid, '%s\n', header);
fprintf(fid, [repmat('%.6g ', 1, size(M, 2) - 1) '%.6g\n'], M.');
fclose(fid);
end

function ts = settle(t, y, tol)
i = find(abs(y) > tol, 1, 'last');
if isempty(i), ts = 0; else, ts = t(i); end
end

function [z, p, k] = zpkLocal(A, B, C)
p = eig(A);
z = eig([A B; C 0], blkdiag(eye(4), 0));
z = z(isfinite(z));
n = numel(p) - numel(z);
k = C*A^(n-1)*B;
end

function O = obsvLocal(A, C)
O = [C; C*A; C*A^2; C*A^3];
end
