function generate_data()
%GENERATE_DATA  Generates every data file and image used by the ball and
%   plate manual, running the Simulink model (ballplate_sim.slx).
%   Run from this folder:  generate_data
%   Output: *.dat (pgfplots tables), num.txt (values quoted in the text),
%           frames.png and gui.png (figures).

D = fileparts(mfilename('fullpath'));
src = fullfile(D, '..', '..', '..', '..', 'src', 'ball_plate');
addpath(src);
old = cd(src); cleanup = onCleanup(@() cd(old));
set(0, 'DefaultFigureVisible', 'off');

bp_build_model();
bp = BallPlate();
P = bp.P;
num = fopen(fullfile(D, 'num.txt'), 'w');
pr = @(varargin) fprintf(num, varargin{:});

%% ---------- Linear analysis ----------
lin = bp.Lin;
pr('Kx = %s\nKy = %s\n', mat2str(P.Kx, 4), mat2str(P.Ky, 4));
pr('Ax = %s\nBx = %s\n', mat2str(lin.x.A, 4), mat2str(lin.x.B, 4));
pr('Ay = %s\nBy = %s\n', mat2str(lin.y.A, 4), mat2str(lin.y.B, 4));
pr('poles_OL_x = %s\npoles_CL_x = %s\n', mat2str(lin.x.poles_OL.', 4), mat2str(lin.x.poles_CL.', 4));
pr('poles_OL_y = %s\npoles_CL_y = %s\n', mat2str(lin.y.poles_OL.', 4), mat2str(lin.y.poles_CL.', 4));
pr('Jb = %.4g  mb = %.4g  Jplate = %.4g  Jf = %.4g  Jrot = %.4g  Ja = %.4g  Jbt = %.4g\n', P.Jb, P.mb, ...
    P.mplate*(2*P.a)^2/12, P.Jf, P.eta_g*P.Kg^2*P.Jm, P.Ja, P.Jbt);
pr('kv = %.4g  beq = %.4g  x_max = %.4g\n', P.kv, P.beq, P.x_max);
Kin = [0 0 P.Kp_a P.Kd_a];
pr('poles_inner_x = %s\npoles_inner_y = %s\n', mat2str(eig(lin.x.A - lin.x.B*Kin).', 4), mat2str(eig(lin.y.A - lin.y.B*Kin).', 4));
Kc  = [-P.Kp_a*P.Kp_x, -P.Kp_a*P.Kd_x, P.Kp_a, P.Kd_a];
pr('poles_cascade_PD_x = %s\n', mat2str(eig(lin.x.A - lin.x.B*Kc).', 4));
% Effect of a camera delay on the LQR (continuous approx: Pade on the ball measurement)
for d = [0 0.01 0.03 0.05]
    pr('delay %.3f s: %s\n', d, mat2str(delayPoles(lin.x, P.Kx, d).', 4));
end

%% ---------- Simulations ----------
bp.clearSignals(); bp.setRef('point', [0 0]); bp.enable(true); bp.setVoltage(0, 0);
tS = [0 1 1+1e-4 6]'; rS = [0 0; 0 0; 0.08 -0.05; 0.08 -0.05];

% Plate tilted by hand (mode plate)
bp.setMode('plate'); bp.setPlateAngle(deg2rad(-1), deg2rad(0.5)); bp.setInitialState(zeros(8, 1));
res = bp.run(3); save_(D, 'plate_tilt', res);
k = find(max(abs(res.x), abs(res.y)) >= P.x_max - 1e-3, 1);
pr('plate_tilt: reaches rim at %.3f s (theory %.3f s), angle of path %.1f deg\n', res.t(k), ...
    sqrt(2*P.x_max/(P.m*P.g/P.mb*sin(deg2rad(1)))), atan2d(res.y(k), res.x(k)));
bp.setPlateAngle(0, 0);

% LQR from (8, -5) cm
bp.setMode('lqr'); bp.setInitialState([0.08 0 -0.05 0 0 0 0 0]);
res = bp.run(5); save_(D, 'lqr_ic', res);
pr('lqr_ic: settle5mm %.2f, Vmax %.2f, max|tilt| %.2f deg\n', settle(res.t, hypot(res.x, res.y), 5e-3), ...
    max(abs([res.Va; res.Vb])), max(abs([res.al_deg; res.be_deg])));

% Point-to-point move, LQR vs cascade
for m = {'lqr', 'cascade'}
    bp.setMode(m{1}); bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tS, rS);
    res = bp.run(6); save_(D, [m{1} '_step'], res);
    pr('%s_step: settle5mm %.2f s after step, overshoot x %.1f %%, final (%.2f, %.2f) cm, Vmax %.2f, max dev from line %.2f mm\n', m{1}, ...
        settle(res.t, hypot(res.x - 0.08, res.y + 0.05), 5e-3) - 1, 100*(max(res.x)/0.08 - 1), 100*res.x(end), 100*res.y(end), ...
        max(abs([res.Va; res.Vb])), 1e3*max(abs(res.x*0.05 + res.y*0.08)/hypot(0.08, 0.05)));
end

% Camera frame rate (cascade and LQR)
for c = {'cascade', 'lqr'}
    bp.setMode(c{1});
    for Tc = [0.04 0.02 0.01]
        bp.setParam('Tcam', Tc); bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tS, rS);
        res = bp.run(6);
        if strcmp(c{1}, 'cascade'), save_(D, sprintf('cam_%d', round(1/Tc)), res); end
        pr('cam %s %d fps: settle %.2f overshoot %.1f %%\n', c{1}, round(1/Tc), ...
            settle(res.t, hypot(res.x - 0.08, res.y + 0.05), 5e-3) - 1, 100*(max(res.x)/0.08 - 1));
    end
end
bp.setParam('Tcam', P.Tcam);
% Camera latency sweep (LQR)
bp.setMode('lqr');
for dl = [0 1 2 3]
    bp.setParam('cam_delay', dl); bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tS, rS);
    res = bp.run(6);
    pr('latency %d frames: settle %.2f overshoot %.1f %%\n', dl, settle(res.t, hypot(res.x - 0.08, res.y + 0.05), 5e-3) - 1, ...
        100*(max(res.x)/0.08 - 1));
end
bp.setParam('cam_delay', P.cam_delay); bp.clearSignals();

% Circle tracking
for c = {'lqr', 'cascade'}
    bp.setMode(c{1}); bp.setInitialState([0.06 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.06, 0.2);
    res = bp.run(15); save_(D, [c{1} '_circle'], res); kk = res.t > 5;
    rad = hypot(res.x(kk), res.y(kk)); E = exp(-1i*2*pi*0.2*res.t(kk));
    g = sum((res.x(kk) + 1i*res.y(kk)).*E)/sum((res.rx(kk) + 1i*res.ry(kk)).*E);
    pr('%s circle 6cm 0.2Hz: radius %.2f cm (%.2f-%.2f), gain %.3f lag %.1f deg\n', c{1}, 100*mean(rad), 100*min(rad), ...
        100*max(rad), abs(g), -rad2deg(angle(g)));
end
% Figure of eight and square (LQR)
bp.setMode('lqr'); bp.setInitialState(zeros(8, 1)); bp.setRef('eight', [0 0], 0.07, 0.15);
res = bp.run(15); save_(D, 'lqr_eight', res); kk = res.t > 5;
pr('eight: rms err %.2f cm\n', 100*sqrt(mean((res.x(kk) - res.rx(kk)).^2 + (res.y(kk) - res.ry(kk)).^2)));
bp.setInitialState(zeros(8, 1)); bp.setRef('square', [0 0], 0.06, 0.1);
res = bp.run(20); save_(D, 'lqr_square', res);
% Large fast circle (coupling)
bp.setInitialState([0.09 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.09, 0.4);
res = bp.run(12); save_(D, 'lqr_circle_fast', res); kk = res.t > 4;
rad = hypot(res.x(kk), res.y(kk));
pr('fast circle 9cm 0.4Hz: radius %.2f cm (%.2f-%.2f), Vmax %.2f, max tilt %.2f\n', 100*mean(rad), 100*min(rad), 100*max(rad), ...
    max(abs([res.Va; res.Vb])), max(abs([res.al_deg; res.be_deg])));
bp.setRef('point', [0 0]);

% Diagonal tap
tp = [0 1 1+1e-4 1.05 1.05+1e-4 4]'; fp = [0 0; 0 0; 0.2 0.2; 0.2 0.2; 0 0; 0 0];
for c = {'lqr', 'cascade'}
    bp.setMode(c{1}); bp.setInitialState(zeros(8, 1)); bp.setDisturbanceSignal(tp, fp);
    res = bp.run(4); save_(D, [c{1} '_tap'], res);
    pr('%s tap: max dist %.2f cm, settle2mm %.2f s after tap\n', c{1}, 100*max(hypot(res.x, res.y)), ...
        settle(res.t, hypot(res.x, res.y), 2e-3) - 1);
end
bp.clearSignals();

% Q_x sweep
bp.setMode('lqr');
for q = [100 500 2500]
    bp.setParam('Q', diag([q P.Q(2,2) P.Q(3,3) P.Q(4,4) P.Q(5,5)])); bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tS, rS);
    res = bp.run(6); save_(D, sprintf('qsweep_%d', q), res);
    pr('qsweep Qx=%d: Kx %s settle %.2f overshoot %.1f %% Vmax %.2f\n', q, mat2str(bp.P.Kx, 3), ...
        settle(res.t, hypot(res.x - 0.08, res.y + 0.05), 5e-3) - 1, 100*(max(res.x)/0.08 - 1), max(abs([res.Va; res.Vb])));
end
bp.setParam('Q', P.Q); bp.clearSignals();

% Noise
bp.setParam('noise_on', 1); bp.setInitialState([0.08 0 -0.05 0 0 0 0 0]); bp.setRef('point', [0 0]);
res = bp.run(5); save_(D, 'lqr_noise', res); kk = res.t > 3;
pr('noise: pos std %.3f mm, tilt std %.3f deg, V std %.3f\n', 1e3*std(hypot(res.x(kk), res.y(kk))), std(res.al_deg(kk)), std(res.Va(kk)));
bp.setParam('noise_on', 0);
res = bp.run(5); kk = res.t > 3;
pr('quantization only: pos std %.3f mm, V std %.3f\n', 1e3*std(hypot(res.x(kk), res.y(kk))), std(res.Va(kk)));

% Camera: measured vs true ball position (one frame of latency)
bp.setMode('lqr'); bp.setInitialState([0.06 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.06, 0.5);
res = bp.run(4); k = res.t >= 3 & res.t <= 3.3;
writeDat(fullfile(D, 'camera.dat'), 't x xm', [res.t(k) 100*res.x(k) 100*res.xm(k)]);
bp.setRef('point', [0 0]);

%% ---------- Images ----------
bp.setMode('lqr'); bp.setInitialState(zeros(8, 1)); bp.setRef('circle', [0 0], 0.08, 0.25);
mv = bp.run(5);
fig = figure('Color', 'w', 'Position', [0 0 1600 420]);
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'none', 'Padding', 'compact');
ts = [0.4 1.6 2.6 4.6];
for i = 1:numel(ts)
    ax = nexttile(tl); h = bp_draw(ax, P); j = find(mv.t >= ts(i), 1);
    k0 = find(mv.t >= ts(i) - 0.6, 1); kk = k0:10:j;
    set(h.trail, 'XData', nan, 'YData', nan, 'ZData', nan);
    for q = kk, bp_draw(ax, P, h, mv.x(q), mv.y(q), mv.al(q), mv.be(q), mv.rx(q), mv.ry(q)); end
    bp_draw(ax, P, h, mv.x(j), mv.y(j), mv.al(j), mv.be(j), mv.rx(j), mv.ry(j));
    ax.XTickLabel = {}; ax.YTickLabel = {}; ax.ZTickLabel = {};
    xlabel(ax, ''); ylabel(ax, ''); zlabel(ax, '');
    title(ax, sprintf('t = %.1f s\n(x, y) = (%+.1f, %+.1f) cm   \\alpha = %+.1f°  \\beta = %+.1f°', mv.t(j), ...
        mv.x_cm(j), mv.y_cm(j), mv.al_deg(j), mv.be_deg(j)), 'FontWeight', 'normal', 'FontSize', 12);
end
exportgraphics(fig, fullfile(D, 'frames.png'), 'Resolution', 150);
close(fig);
pr('frames at t = %s (LQR, circle 8 cm at 0.25 Hz)\n', mat2str(ts));

set(0, 'DefaultFigureVisible', 'on');
bp = BallPlate(); bp_gui(bp);
f = findall(groot, 'Type', 'figure', 'Name', 'Ball and plate — live Simulink');
c = findall(f, 'Type', 'uidropdown');
dr = c(arrayfun(@(x) any(strcmp(x.Items, 'Circle')), c)); dr.Value = 1; dr.ValueChangedFcn(dr, []);
b = findall(f, 'Type', 'uibutton'); bs = b(strcmp({b.Text}, '▶ Start')); bs.ButtonPushedFcn(bs, []);
w0 = tic; while bp.LastTime < 8 && toc(w0) < 60, pause(0.1); end
exportapp(f, fullfile(D, 'gui.png'));
bp.stop(); pause(0.5); rl = bp.lastResult(); delete(f);
pr('gui run: t end %.2f, CmdRef %s\n', rl.t(end), mat2str(bp.CmdRef, 3));
fclose(num);
fprintf('Manual data written to %s\n', D);
end

%% ======================= helpers =======================
function save_(D, name, res)
k = 1:5:numel(res.t);                                % 5 ms resolution
writeDat(fullfile(D, [name '.dat']), 't x y al be Va Vb rx ry', ...
    [res.t(k) res.x_cm(k) res.y_cm(k) res.al_deg(k) res.be_deg(k) res.Va(k) res.Vb(k) res.rx_cm(k) res.ry_cm(k)]);
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

function p = delayPoles(L, K, d)
%DELAYPOLES  Closed-loop poles of the LQR (no integrator) when x and xd
%   reach the controller through a delay d, approximated by a first-order
%   lag of time constant d/2 on each (z1 ~ x(t-d), z2 ~ xd(t-d)).
A = L.A; B = L.B; K4 = K(1:4);
if d == 0, p = eig(A - B*K4); return; end
Ad = [A, zeros(4,2); 2/d 0 0 0 -2/d 0; 0 2/d 0 0 0 -2/d];
Kd = [0 0 K4(3) K4(4) K4(1) K4(2)];
p = eig(Ad - [B; 0; 0]*Kd);
end
