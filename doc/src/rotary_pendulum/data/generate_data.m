function generate_data()
%GENERATE_DATA  Generates every data file and image used by the rotary
%   pendulum manual, running the Simulink model (rotpend_sim.slx).
%   Run from this folder:  generate_data
%   Output: *.dat (pgfplots tables), num.txt (values quoted in the text),
%           frames.png and gui.png (figures).

D = fileparts(mfilename('fullpath'));
src = fullfile(D, '..', '..', '..', '..', 'src', 'rotary_pendulum');
addpath(src);
old = cd(src); cleanup = onCleanup(@() cd(old));
set(0, 'DefaultFigureVisible', 'off');

rp_build_model();
rp = RotaryPendulum();
P = rp.P; d45 = deg2rad(45);
num = fopen(fullfile(D, 'num.txt'), 'w');
pr = @(varargin) fprintf(num, varargin{:});

%% ---------- Linear analysis ----------
lin = rp.Lin;
pr('K_up = %s\nK_dn = %s\n', mat2str(P.K_up, 4), mat2str(P.K_dn, 4));
pr('A_up = %s\nB_up = %s\n', mat2str(lin.up.A, 4), mat2str(lin.up.B, 4));
pr('A_dn = %s\nB_dn = %s\n', mat2str(lin.dn.A, 4), mat2str(lin.dn.B, 4));
pr('poles_OL_up = %s\npoles_CL_up = %s\n', mat2str(lin.up.poles_OL.', 4), mat2str(lin.up.poles_CL.', 4));
pr('poles_OL_dn = %s\npoles_CL_dn = %s\n', mat2str(lin.dn.poles_OL.', 4), mat2str(lin.dn.poles_CL.', 4));
pr('J0 = %.4g  Ja = %.4g  Jr = %.4g  Jp = %.4g  hc = %.4g\n', P.J0, P.Ja, P.Jr, P.Jp, P.mp*P.Lr*P.lp);
pr('beq = %.4g  b_emf = %.4g  wn_down = %.4g\n', P.Dr + P.kt*P.km/P.Rm, P.kt*P.km/P.Rm, sqrt(P.mp*P.g*P.lp/P.Ja));
for tag = {'up', 'dn'}
    L = lin.(tag{1});
    for o = 1:2
        [z, p, k] = zpkLocal(L.A, L.B, L.C(o,:));
        pr('zpk_%s_y%d: zeros=%s  poles=%s  k=%.4g\n', tag{1}, o, mat2str(z.', 4), mat2str(p.', 4), k);
    end
    Co = ctrbLocal(L.A, L.B);
    pr('rank_ctrb_%s = %d  cond = %.3g\n', tag{1}, rank(Co), cond(Co));
    pr('rank_obs_%s: theta only %d, alpha only %d\n', tag{1}, ...
        rank(obsvLocal(L.A, L.C(1,:))), rank(obsvLocal(L.A, L.C(2,:))));
end
pid = -[P.Kp_th P.Kd_th P.Kp_al P.Kd_al];
pr('poles_PID = %s\n', mat2str(eig(lin.up.A - lin.up.B*pid).', 4));

% Bode of the linear models
f = logspace(-1, 2, 300); w = 2*pi*f;
for tag = {'up', 'dn'}
    L = lin.(tag{1});
    for o = 1:2
        H = arrayfun(@(wk) L.C(o,:)*((1i*wk*eye(4) - L.A)\L.B), w);
        nm = {'th', 'al'};
        writeDat(fullfile(D, sprintf('bode_%s_%s.dat', tag{1}, nm{o})), 'f mag ph', ...
            [f(:) 20*log10(abs(H(:))) rad2deg(unwrap(angle(H(:))))]);
    end
end
% LQR closed-loop poles versus Q_alpha
rows = [];
for q = logspace(-1, 3, 40)
    K = rp_lqr(lin.up.A, lin.up.B, diag([q P.Qup(2,2) P.Qup(3,3) P.Qup(4,4)]), P.Rup);
    ev = eig(lin.up.A - lin.up.B*K);
    rows = [rows; repmat(q, 4, 1) real(ev) imag(ev)]; %#ok<AGROW>
end
writeDat(fullfile(D, 'lqr_locus.dat'), 'q re im', rows);

% Velocity estimation: quantized alpha, raw difference vs filtered
Ts = P.Ts; t = (0:Ts:1)'; alr = 0.3*sin(2*pi*1.5*t); alq = round(alr/P.res_al)*P.res_al;
raw = [0; diff(alq)/Ts]; a = exp(-Ts/P.tau_v); v = zeros(size(t));
for k = 2:numel(t), v(k) = a*v(k-1) + (1 - a)*(alq(k) - alq(k-1))/Ts; end
writeDat(fullfile(D, 'velest.dat'), 't true raw filt', [t 0.3*2*pi*1.5*cos(2*pi*1.5*t) raw v]);

%% ---------- Simulations ----------
stepSig = @(t0, A, T) deal([0 t0 t0+1e-4 T]', [0 0 A A]');
rp.clearSignals(); rp.setRef('const', 0);

rp.setMode('lqr'); rp.setInitialState([0 0 deg2rad(10) 0]);
res = rp.run(4); save_(D, 'lqr_ic', res);
pr('lqr_ic: Vmax %.2f, settle1deg %.2f, max|th| %.1f\n', max(abs(res.Vact)), settle(res.t, res.al_deg, 1), max(abs(res.th_deg)));

[t, r] = stepSig(1, d45, 6);
rp.setInitialState([0 0 0 0]); rp.setRefSignal(t, r);
res = rp.run(6); save_(D, 'lqr_step', res);
pr('lqr_step (rate limited): min th %.2f, settle5%% %.2f, max|al| %.2f, Vmax %.2f\n', min(res.th_deg), ...
    settle(res.t, res.th_deg - 45, 2.25) - 1, max(abs(res.al_deg)), max(abs(res.Vact)));

rp.clearSignals(); rp.setRef('const', 0);
rp.setDisturbanceSignal([0 1 1+1e-4 1.05 1.05+1e-4 4]', [0 0 0.1 0.1 0 0]');
res = rp.run(4); save_(D, 'lqr_push', res);
pr('lqr_push: max|al| %.2f, max|th| %.2f, Vmax %.2f, settle %.2f\n', max(abs(res.al_deg)), max(abs(res.th_deg)), ...
    max(abs(res.Vact)), settle(res.t, res.al_deg, 1));
rp.clearSignals();

rp.setMode('swingup'); rp.setInitialState([0 0 pi 0]);
res = rp.run(8); save_(D, 'swingup', res);
k = find(res.caught > 0.5, 1);
pr('swingup: catch %.3f s, max|th| %.1f, Vmax %.1f, E0 %.4g\n', res.t(k), max(abs(res.th_deg)), max(abs(res.Vact)), ...
    P.mp*P.g*P.lp*(-2));
swing = res;
for c = {{'Vmax', 6}, {'mp', 0.048}, {'Lp', 0.18}}
    rp.setParam(c{1}{1}, c{1}{2}); rp.setInitialState([0 0 pi 0]);
    res = rp.run(8); k = find(res.caught > 0.5, 1);
    pr('swingup %s=%g: catch %.3f s, max|th| %.1f, final al %.2f\n', c{1}{1}, c{1}{2}, res.t(k), max(abs(res.th_deg)), res.al_deg(end));
    rp.setParam(c{1}{1}, P.(c{1}{1}));
end

rp.setMode('pid'); rp.setInitialState([0 0 deg2rad(10) 0]);
res = rp.run(4); save_(D, 'pid_ic', res);
pr('pid_ic: Vmax %.2f, settle %.2f\n', max(abs(res.Vact)), settle(res.t, res.al_deg, 1));
[t, r] = stepSig(1, d45, 6);
rp.setInitialState([0 0 0 0]); rp.setRefSignal(t, r);
res = rp.run(6); save_(D, 'pid_step', res);
pr('pid_step: min th %.2f, settle5%% %.2f, final th %.2f\n', min(res.th_deg), settle(res.t, res.th_deg - 45, 2.25) - 1, res.th_deg(end));

[t, r] = stepSig(1, deg2rad(90), 6);
rp.setMode('down'); rp.setInitialState([0 0 pi 0]); rp.setRefSignal(t, r);
res = rp.run(6); save_(D, 'down_step', res);
sw = @(res) max(abs(wrapDeg(res.al_deg(res.t > 4) - 180)));
pr('down_step 90: sway t>4 %.2f, max sway %.2f, settle %.2f\n', sw(res), max(abs(wrapDeg(res.al_deg - 180))), ...
    settle(res.t, res.th_deg - 90, 4.5) - 1);
Kn = rp.P.K_dn; Kn(3:4) = 0; Kd = rp.P.K_dn;
rp.setParamRaw('K_dn', Kn);
res = rp.run(6); save_(D, 'down_nosway', res);
pr('down_nosway 90: sway t>4 %.2f, max sway %.2f\n', sw(res), max(abs(wrapDeg(res.al_deg - 180))));
rp.setParamRaw('K_dn', Kd); rp.clearSignals();

% Q_theta and R sweeps (LQR from 10 deg)
rp.setMode('lqr'); rp.setRef('const', 0); rp.setInitialState([0 0 deg2rad(10) 0]);
for q = [5 20 80]
    rp.setParam('Qup', diag([q P.Qup(2,2) P.Qup(3,3) P.Qup(4,4)]));
    res = rp.run(3); save_(D, sprintf('qsweep_%d', q), res);
    pr('qsweep Qth=%d: K %s Vmax %.2f settle %.2f max|th| %.1f\n', q, mat2str(rp.P.K_up, 3), max(abs(res.Vact)), ...
        settle(res.t, res.al_deg, 1), max(abs(res.th_deg)));
end
rp.setParam('Qup', P.Qup);
for R = [0.2 5]
    rp.setParam('Rup', R);
    res = rp.run(3); save_(D, sprintf('rsweep_%g', R), res);
    pr('rsweep %g: K %s Vmax %.2f settle %.2f\n', R, mat2str(rp.P.K_up, 3), max(abs(res.Vact)), settle(res.t, res.al_deg, 1));
end
rp.setParam('Rup', P.Rup);

% Robustness: true pendulum mass differs, gains stay nominal
Knom = rp.P.K_up;
for mp = [0.012 0.048 0.072]
    rp.setParam('mp', mp); rp.setParamRaw('K_up', Knom);
    res = rp.run(4); save_(D, sprintf('msweep_%g', mp), res);
    pr('msweep %g: settle %.2f final al %.2f stable %d\n', mp, settle(res.t, res.al_deg, 1), res.al_deg(end), max(abs(res.al_deg(res.t > 3))) < 2);
end
rp.setParam('mp', P.mp);

% Sine tracking
for fr = [0.2 0.5 1]
    rp.setInitialState([0 0 0 0]); rp.setRef('sine', 0, d45, fr);
    res = rp.run(15); kk = res.t > 5; E = exp(-1i*2*pi*fr*res.t(kk));
    g = sum(res.th(kk).*E)/sum(res.r(kk).*E);
    pr('sine %g Hz: gain %.3f lag %.1f\n', fr, abs(g), -rad2deg(angle(g)));
    if fr == 0.5, save_(D, 'sine_0.5', res); end
end
rp.setRef('const', 0);

% Encoder noise on
rp.setParam('noise_on', 1); rp.setInitialState([0 0 deg2rad(10) 0]);
res = rp.run(4); save_(D, 'lqr_noise', res);
kk = res.t > 2;
pr('noise: al std %.3f deg, V std %.2f, th std %.2f deg\n', std(res.al_deg(kk)), std(res.Vact(kk)), std(res.th_deg(kk)));
rp.setParam('noise_on', 0);
res = rp.run(4); kk = res.t > 2;
pr('quantization only: V std %.2f\n', std(res.Vact(kk)));

%% ---------- Images ----------
fig = figure('Color', 'w', 'Position', [0 0 1600 420]);
tl = tiledlayout(fig, 1, 5, 'TileSpacing', 'none', 'Padding', 'compact');
ts = [0 1.2 1.6 2.15 4];
for i = 1:numel(ts)
    ax = nexttile(tl); h = rp_draw(ax, P); j = find(swing.t >= ts(i), 1);
    rp_draw(ax, P, h, swing.th(j), swing.al(j), swing.r(j));
    ax.XTickLabel = {}; ax.YTickLabel = {}; ax.ZTickLabel = {};
    xlabel(ax, ''); ylabel(ax, ''); zlabel(ax, '');
    title(ax, sprintf('t = %.2f s\n\\theta = %+.0f°   \\alpha = %+.0f°', swing.t(j), swing.th_deg(j), swing.al_deg(j)), ...
        'FontWeight', 'normal', 'FontSize', 13);
end
exportgraphics(fig, fullfile(D, 'frames.png'), 'Resolution', 150);
close(fig);
pr('frames at t = %s\n', mat2str(ts));

set(0, 'DefaultFigureVisible', 'on');
rp = RotaryPendulum(); rp_gui(rp);
f = findall(groot, 'Type', 'figure', 'Name', 'Rotary pendulum — live Simulink');
c = findall(f, 'Type', 'uidropdown');
c(arrayfun(@(x) any(strcmp(x.Items, 'Down (α=180°)')), c)).Value = 'Down (α=180°)';
c(arrayfun(@(x) any(strcmp(x.Items, '2  Swing-up + LQR')), c)).Value = 2;
b = findall(f, 'Type', 'uibutton'); bs = b(strcmp({b.Text}, '▶ Start')); bs.ButtonPushedFcn(bs, []);
w0 = tic; while rp.LastTime < 4.5 && toc(w0) < 60, pause(0.1); end
exportapp(f, fullfile(D, 'gui.png'));
rp.stop(); pause(0.5); rl = rp.lastResult(); delete(f);
pr('gui run: max|th| %.1f, catch %.3f, x0 %s, CmdCtrl %s, CmdRef %s\n', max(abs(rl.th_deg)), ...
    rl.t(find(rl.caught > 0.5, 1)), mat2str(rp.P.x0', 3), mat2str(rp.CmdCtrl, 3), mat2str(rp.CmdRef, 3));
fclose(num);
fprintf('Manual data written to %s\n', D);
end

%% ======================= helpers =======================
function save_(D, name, res)
k = 1:5:numel(res.t);                                % 5 ms resolution
writeDat(fullfile(D, [name '.dat']), 't th al V r caught E', ...
    [res.t(k) res.th_deg(k) res.al_deg(k) res.Vact(k) res.r_deg(k) res.caught(k) 1e3*res.E(k)]);
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

function d = wrapDeg(d)
d = mod(d + 180, 360) - 180;
end

function [z, p, k] = zpkLocal(A, B, C)
p = eig(A);
z = eig([A B; C 0], blkdiag(eye(4), 0));
z = z(isfinite(z));
n = numel(p) - numel(z);
k = C*A^(n-1)*B;
end

function Co = ctrbLocal(A, B)
Co = [B A*B A^2*B A^3*B];
end

function O = obsvLocal(A, C)
O = [C; C*A; C*A^2; C*A^3];
end
