%% EXAMPLES  Walkthrough of the rotary (Furuta) pendulum code interface.
% Run section by section (Ctrl+Enter). Requires MATLAB + Simulink.
% The Control System Toolbox is optional (without it, rp_lqr solves Riccati).
% The code interface uses radians; results also carry *_deg fields.

%% 0) Create/load the model and the interface
clear; close all; clc
rp_build_model();          % (re)generates rotpend_sim.slx — only needed the first time
rp = RotaryPendulum();     % control object
disp('LQR gain (up):'); disp(rp.P.K_up)
disp('Open-loop poles (up):');   disp(rp.Lin.up.poles_OL.')
disp('Closed-loop poles (up):'); disp(rp.Lin.up.poles_CL.')

%% 1) LQR stabilization from alpha = 10 deg
rp.clearSignals();
rp.setInitialState([0 0 deg2rad(10) 0]);
rp.setMode('lqr'); rp.enable(true); rp.setVoltage(0);
rp.setRef('const', 0);
res = rp.run(4);
rp_plot_results(res, 'LQR: stabilization from \alpha_0 = 10°');

%% 2) Arm positioning: 45 deg step as an external signal
t = [0 1 1.001 6]';  r = deg2rad([0 0 45 45])';
rp.setInitialState([0 0 0 0]);
rp.setRefSignal(t, r);               % activates the 'external' reference type
res = rp.run(6);
rp_plot_results(res, 'LQR: 45° arm step (note the initial inverse response)');

%% 3) Disturbance rejection: scheduled tap at the pendulum tip
rp.setRef('const', 0);
rp.setDisturbanceSignal([0 1 1.001 1.05 1.051 4]', [0 0 0.1 0.1 0 0]');  % 0.1 N for 50 ms
res = rp.run(4);
rp_plot_results(res, 'LQR: 0.1 N x 50 ms tap at t = 1 s');
rp.clearSignals();

%% 4) Energy-based swing-up + LQR catch (from hanging)
rp.setInitialState([0 0 pi 0]);
rp.setMode('swingup'); rp.setRef('const', 0);
res = rp.run(8);
rp_plot_results(res, 'Swing-up + LQR');
rp.animate(res);

%% 5) PID on the pendulum + PD on the arm
rp.setInitialState([0 0 deg2rad(10) 0]);
rp.setMode('pid');
res = rp.run(4);
rp_plot_results(res, 'PID pendulum + PD arm');

%% 6) Down mode: move the arm with a square wave without sway
rp.setInitialState([0 0 pi 0]);
rp.setMode('down'); rp.setRef('square', 0, deg2rad(45), 0.2);
res = rp.run(10);
rp_plot_results(res, 'Down: ±45° square reference');
rp.animate(res);

%% 7) Open-loop identification: voltage chirp around alpha = pi
T = 20; dt = rp.P.h; tt = (0:dt:T)';
f0 = 0.5; f1 = 5; A = 1.0;
u = A*sin(2*pi*(f0*tt + (f1 - f0)/(2*T)*tt.^2));
rp.setInitialState([0 0 pi 0]);
rp.setMode('open'); rp.setRef('const', 0);
rp.setVoltageSignal(tt, u);
res = rp.run(T);
rp.clearSignals();

% Linear model prediction (discretized with expm, no toolboxes)
lin = rp.Lin.dn;
Md  = expm([lin.A lin.B; zeros(1, 5)]*dt);
Ad = Md(1:4, 1:4); Bd = Md(1:4, 5);
uu = interp1(res.t, res.Vact, tt, 'previous', 0);
z = zeros(4, numel(tt));
for k = 1:numel(tt) - 1, z(:, k+1) = Ad*z(:, k) + Bd*uu(k); end
figure('Name', 'Identification', 'Color', 'w');
subplot(2,1,1); plot(res.t, res.th_deg, tt, rad2deg(z(1,:)), '--'); grid on
ylabel('\theta [deg]'); legend('nonlinear (Simulink)', 'linear');
subplot(2,1,2); plot(res.t, rad2deg(mod(res.al, 2*pi) - pi), tt, rad2deg(z(3,:)), '--'); grid on
ylabel('\alpha - \pi [deg]'); xlabel('t [s]');
title('Differences: Coulomb friction and large-angle nonlinearity');

%% 8) Parameter sweep from code (e.g. pendulum mass)
rp.setMode('lqr'); rp.setInitialState([0 0 deg2rad(10) 0]);
figure('Name', 'mp sweep', 'Color', 'w'); hold on; grid on
for mp = [0.012 0.024 0.048]
    rp.setParam('mp', mp);            % recomputes inertias and K automatically
    res = rp.run(3);
    plot(res.t, res.al_deg, 'DisplayName', sprintf('m_p = %.0f g', 1e3*mp));
end
legend; ylabel('\alpha [deg]'); xlabel('t [s]');
rp.setParam('mp', 0.024);

%% 9) Live mode from code (no GUI): commands while simulating
rp.setInitialState([0 0 deg2rad(5) 0]); rp.setMode('lqr'); rp.setRef('const', 0);
rp.addTelemetryCallback(@(t, d) fprintf('t=%5.2f  th=%+6.1f deg  al=%+5.1f deg\n', ...
    t, rad2deg(d(1)), rad2deg(d(3))));
rp.TelemetryRate = 2;                 % 2 lines per second
rp.start();  pause(3)
rp.setRef('sine', 0, deg2rad(45), 0.2);  pause(5)
rp.push(0.1, 0.05);                      pause(3)
rp.stop();   rp.clearCallbacks(); rp.TelemetryRate = 30;
res = rp.lastResult(); rp_plot_results(res, 'Live session from code');

%% 10) Live graphical interface
rp_gui(rp);
