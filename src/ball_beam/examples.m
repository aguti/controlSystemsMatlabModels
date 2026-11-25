%% EXAMPLES  Walkthrough of the ball and beam code interface.
% Run section by section (Ctrl+Enter). Requires MATLAB + Simulink.
% The Control System Toolbox is optional (without it, bb_lqr solves Riccati).
% The code interface uses metres and radians; results also carry *_cm/*_deg fields.

%% 0) Create/load the model and the interface
clear; close all; clc
bb_build_model();          % (re)generates ballbeam_sim.slx — only needed the first time
bb = BallBeam();           % control object
disp('LQR gain [x-r, xd, alpha, alphad, int]:'); disp(bb.P.K)
disp('Open-loop poles:');   disp(bb.Lin.poles_OL.')
disp('Closed-loop poles (LQR + integral):'); disp(bb.Lin.poles_CL.')

%% 1) LQR: bring the ball from x = 10 cm to the centre
bb.clearSignals();
bb.setInitialState([0.10 0 0 0]);
bb.setMode('lqr'); bb.enable(true); bb.setVoltage(0);
bb.setRef('const', 0);
res = bb.run(5);
bb_plot_results(res, 'LQR: from x_0 = 10 cm to the centre');
bb.animate(res);

%% 2) 10 cm reference step: LQR vs cascade PID
t = [0 1 1.001 6]';  r = [0 0 0.10 0.10]';
bb.setInitialState([0 0 0 0]);
bb.setRefSignal(t, r);               % activates the 'external' reference type
figure('Name', 'LQR vs cascade', 'Color', 'w'); hold on; grid on
for m = {'lqr', 'cascade'}
    bb.setMode(m{1});
    res = bb.run(6);
    plot(res.t, res.x_cm, 'DisplayName', m{1});
end
plot(res.t, res.r_cm, 'k--', 'DisplayName', 'reference (rate limited)');
legend('Location', 'southeast'); xlabel('t [s]'); ylabel('x [cm]');

%% 3) Why the weight feedforward matters (cascade, no integral action)
bb.setMode('cascade');
figure('Name', 'Weight feedforward', 'Color', 'w'); hold on; grid on
for ff = [1 0]
    bb.setParams(struct('ff_on', ff, 'Ki_x', 0));
    res = bb.run(6);
    plot(res.t, res.x_cm, 'DisplayName', sprintf('ff\\_on = %d', ff));
end
plot(res.t, res.r_cm, 'k--', 'DisplayName', 'reference');
legend('Location', 'southeast'); xlabel('t [s]'); ylabel('x [cm]');
title('Without feedforward the ball weight leaves a steady-state error');
bb.setParams(struct('ff_on', 1, 'Ki_x', 0.1));

%% 4) Disturbance rejection: tap on the ball
bb.setMode('lqr'); bb.setRef('const', 0); bb.setInitialState([0 0 0 0]);
bb.setDisturbanceSignal([0 1 1.001 1.05 1.051 4]', [0 0 0.2 0.2 0 0]');  % 0.2 N for 50 ms
res = bb.run(4);
bb_plot_results(res, 'LQR: 0.2 N x 50 ms tap at t = 1 s');
bb.clearSignals();

%% 5) Mode 'beam': the ball alone is unstable (double integrator)
bb.setMode('beam'); bb.setBeamAngle(deg2rad(-2));   % -2 deg: the +x end goes down
bb.setInitialState([0 0 0 0]);
res = bb.run(3);
bb_plot_results(res, 'Beam at -2°: the ball rolls to the end stop');
bb.animate(res);
bb.setBeamAngle(0);

%% 6) Sine tracking with LQR
bb.setMode('lqr'); bb.setInitialState([0 0 0 0]);
bb.setRef('sine', 0, 0.10, 0.25);
res = bb.run(16);
bb_plot_results(res, 'LQR: ±10 cm sine at 0.25 Hz');

%% 7) Inner loop alone: beam angle step (ball removed by making it very light)
bb.setParam('m', 1e-5);
bb.setMode('beam'); bb.setBeamAngle(deg2rad(5)); bb.setInitialState([0 0 0 0]);
res = bb.run(1);
lin = bb.Lin;                                    % linear model with m ~ 0
Acl = lin.A - lin.B*[0 0 bb.P.Kp_a bb.P.Kd_a];   % PD on the measured angle (no filter)
tt = res.t; z = zeros(4, numel(tt)); dt = tt(2) - tt(1);
for k = 1:numel(tt) - 1
    z(:, k+1) = z(:, k) + dt*(Acl*z(:, k) + lin.B*bb.P.Kp_a*deg2rad(5));
end
figure('Name', 'Inner loop', 'Color', 'w');
plot(tt, res.al_deg, tt, rad2deg(z(3, :)), '--'); grid on
legend('Simulink (Coulomb, quantization, filter)', 'linear PD'); xlabel('t [s]'); ylabel('\alpha [deg]');
bb.setParam('m', 0.067); bb.setBeamAngle(0);

%% 8) Robustness: heavier/lighter ball with the nominal gains
bb.setMode('lqr'); bb.setInitialState([0 0 0 0]);
bb.setRefSignal(t, r);
Knom = bb.P.K;
figure('Name', 'Ball mass', 'Color', 'w'); hold on; grid on
for m = [0.03 0.067 0.134]
    bb.setParamRaw('m', m);           % true ball changes; K keeps the nominal design
                                      % (the feedforward m g r/kv does use the new m)
    bb.setParamRaw('K', Knom);
    res = bb.run(6);
    plot(res.t, res.x_cm, 'DisplayName', sprintf('m = %.0f g', 1e3*m));
end
legend('Location', 'southeast'); ylabel('x [cm]'); xlabel('t [s]');
bb.setParam('m', 0.067); bb.clearSignals();

%% 9) Live mode from code (no GUI): commands while simulating
bb.setInitialState([0.1 0 0 0]); bb.setMode('lqr'); bb.setRef('const', 0);
bb.addTelemetryCallback(@(t, d) fprintf('t=%5.2f  x=%+6.1f cm  alpha=%+5.1f deg\n', ...
    t, 100*d(1), rad2deg(d(3))));
bb.TelemetryRate = 2;                 % 2 lines per second
bb.start();  pause(3)
bb.setRef('const', 0.08);  pause(3)
bb.push(-0.3, 0.05);       pause(3)
bb.stop();   bb.clearCallbacks(); bb.TelemetryRate = 30;
res = bb.lastResult(); bb_plot_results(res, 'Live session from code');

%% 10) Live graphical interface
bb_gui(bb);
