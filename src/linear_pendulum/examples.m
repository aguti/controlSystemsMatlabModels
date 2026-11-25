%% EXAMPLES  Walkthrough of the linear pendulum code interface.
% Run section by section (Ctrl+Enter). Requires MATLAB + Simulink.
% The Control System Toolbox is optional (without it, cp_lqr solves Riccati).

%% 0) Create/load the model and the interface
clear; close all; clc
cp_build_model();          % (re)generates cartpole_sim.slx — only needed the first time
cp = CartPole();           % control object
disp('LQR gain (up):'); disp(cp.P.K_up)
disp('Closed-loop poles (up):'); disp(cp.Lin.up.poles_CL.')

%% 1) LQR stabilization from 0.15 rad (~8.6°)
cp.clearSignals();
cp.setInitialState([0 0 0.15 0]);
cp.setMode('lqr'); cp.enable(true); cp.setForce(0);
cp.setRef('const', 0);
res = cp.run(6);
cp_plot_results(res, 'LQR: stabilization from \theta_0 = 0.15 rad');

%% 2) Position tracking: 0.3 m step as an external signal
t = [0 1 1.001 8]';  r = [0 0 0.3 0.3]';
cp.setInitialState([0 0 0 0]);
cp.setRefSignal(t, r);               % activates the 'external' reference type
res = cp.run(8);
cp_plot_results(res, 'LQR: position step (note the initial inverse response)');

%% 3) Disturbance rejection: scheduled push at the tip
cp.setRef('const', 0);
cp.setDisturbanceSignal([0 2 2.001 2.1 2.101 6]', [0 0 1 1 0 0]');   % 1 N for 0.1 s
res = cp.run(6);
cp_plot_results(res, 'LQR: 1 N x 0.1 s push at t = 2 s');
cp.clearSignals();

%% 4) Energy-based swing-up + LQR catch (from hanging)
cp.setInitialState([0 0 pi 0]);
cp.setMode('swingup'); cp.setRef('const', 0);
res = cp.run(12);
cp_plot_results(res, 'Swing-up + LQR');
cp.animate(res);

%% 5) PID on the angle + PD on the cart
cp.setInitialState([0 0 0.1 0]);
cp.setMode('pid');
res = cp.run(8);
cp_plot_results(res, 'PID angle + PD cart');

%% 6) Crane mode: carry the load with a square wave without sway
cp.setInitialState([0 0 pi 0]);
cp.setMode('crane'); cp.setRef('square', 0, 0.4, 0.1);
res = cp.run(20);
cp_plot_results(res, 'Crane: ±0.4 m square reference');

%% 7) Open-loop identification: force chirp around theta = pi
T = 20; dt = cp.P.h; tt = (0:dt:T)';
f0 = 0.5; f1 = 3; A = 0.7;
u = A*sin(2*pi*(f0*tt + (f1 - f0)/(2*T)*tt.^2));
cp.setInitialState([0 0 pi 0]);
cp.setMode('open'); cp.setRef('const', 0);
cp.setForceSignal(tt, u);
res = cp.run(T);
cp.clearSignals();

% Linear model prediction (discretized with expm, no toolboxes)
lin = cp.Lin.dn;
Md  = expm([lin.A lin.B; zeros(1, 5)]*dt);
Ad = Md(1:4, 1:4); Bd = Md(1:4, 5);
uu = interp1(res.t, res.Fact, tt, 'previous', 0);
z = zeros(4, numel(tt));
for k = 1:numel(tt) - 1, z(:, k+1) = Ad*z(:, k) + Bd*uu(k); end
figure('Name', 'Identification', 'Color', 'w');
subplot(2,1,1); plot(res.t, res.x, tt, z(1,:), '--'); grid on
ylabel('x [m]'); legend('nonlinear (Simulink)', 'linear');
subplot(2,1,2); plot(res.t, rad2deg(mod(res.th, 2*pi) - pi), tt, rad2deg(z(3,:)), '--'); grid on
ylabel('\theta - \pi [deg]'); xlabel('t [s]');
title('Differences: Coulomb friction and large-angle nonlinearity');

%% 8) Parameter sweep from code (e.g. cart mass)
cp.setMode('lqr'); cp.setInitialState([0 0 0.15 0]);
figure('Name', 'M sweep', 'Color', 'w'); hold on; grid on
for M = [0.3 0.5 1.0 2.0]
    cp.setParam('M', M);              % recomputes K automatically
    res = cp.run(5);
    plot(res.t, res.th_deg, 'DisplayName', sprintf('M = %.1f kg', M));
end
legend; ylabel('\theta [deg]'); xlabel('t [s]');
cp.setParam('M', 0.5);

%% 9) Live mode from code (no GUI): commands while simulating
cp.setInitialState([0 0 0.05 0]); cp.setMode('lqr'); cp.setRef('const', 0);
cp.addTelemetryCallback(@(t, d) fprintf('t=%5.2f  x=%+.3f  th=%+.3f\n', t, d(1), d(3)));
cp.TelemetryRate = 2;                 % 2 lines per second
cp.start();  pause(3)
cp.setRef('sine', 0, 0.2, 0.2);  pause(5)
cp.push(1, 0.1);                 pause(3)
cp.stop();   cp.clearCallbacks(); cp.TelemetryRate = 30;
res = cp.lastResult(); cp_plot_results(res, 'Live session from code');

%% 10) Live graphical interface
cp_gui(cp);
