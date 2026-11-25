%% EXAMPLES  Walkthrough of the ball and plate code interface.
% Run section by section (Ctrl+Enter). Requires MATLAB + Simulink.
% The Control System Toolbox is optional (without it, bp_lqr solves Riccati).
% The code interface uses metres and radians; results also carry *_cm/*_deg fields.

%% 0) Create/load the model and the interface
clear; close all; clc
bp_build_model();          % (re)generates ballplate_sim.slx — only needed the first time
bp = BallPlate();          % control object
disp('LQR gains [e, ed, angle, rate, int]:'); disp(bp.P.Kx); disp(bp.P.Ky)
disp('Open-loop poles (x axis):'); disp(bp.Lin.x.poles_OL.')
disp('Closed-loop poles (x axis):'); disp(bp.Lin.x.poles_CL.')

%% 1) LQR: bring the ball to the centre
bp.clearSignals();
bp.setInitialState([0.08 0 -0.05 0 0 0 0 0]);
bp.setMode('lqr'); bp.enable(true); bp.setVoltage(0, 0);
bp.setRef('point', [0 0]);
res = bp.run(5);
bp_plot_results(res, 'LQR: from (8, -5) cm to the centre');
bp.animate(res);

%% 2) Point-to-point move: LQR vs cascade PID
t = [0 1 1.001 6]';  rxy = [0 0; 0 0; 0.08 -0.05; 0.08 -0.05];
bp.setInitialState(zeros(8, 1));
bp.setRefSignal(t, rxy);             % activates the 'external' reference type
figure('Name', 'LQR vs cascade', 'Color', 'w'); hold on; grid on; axis equal
for m = {'lqr', 'cascade'}
    bp.setMode(m{1});
    res = bp.run(6);
    plot(res.x_cm, res.y_cm, 'DisplayName', m{1});
end
plot(8, -5, 'g+', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', 'target');
legend; xlabel('x [cm]'); ylabel('y [cm]');

%% 3) Circle tracking (r = 6 cm, 0.2 Hz)
bp.clearSignals(); bp.setMode('lqr');
bp.setInitialState([0.06 0 0 0 0 0 0 0]);
bp.setRef('circle', [0 0], 0.06, 0.2);
res = bp.run(15);
bp_plot_results(res, 'LQR: circle r = 6 cm at 0.2 Hz');
bp.animate(res);

%% 4) Figure of eight and square
bp.setInitialState(zeros(8, 1));
bp.setRef('eight', [0 0], 0.07, 0.15);
res = bp.run(15); bp_plot_results(res, 'LQR: figure of eight');
bp.setRef('square', [0 0], 0.06, 0.1);
res = bp.run(20); bp_plot_results(res, 'LQR: square (jumps between corners)');

%% 5) Camera frame rate: same cascade, 25 / 50 / 100 fps
bp.setMode('cascade'); bp.setInitialState(zeros(8, 1)); bp.setRefSignal(t, rxy);
figure('Name', 'Camera frame rate', 'Color', 'w'); hold on; grid on
for Tc = [0.04 0.02 0.01]
    bp.setParam('Tcam', Tc);          % sample times are read when the model compiles
    res = bp.run(6);
    plot(res.t, res.x_cm, 'DisplayName', sprintf('%.0f fps', 1/Tc));
end
legend('Location', 'southeast'); xlabel('t [s]'); ylabel('x [cm]');
bp.setParam('Tcam', 0.02); bp.clearSignals();

%% 6) Disturbance rejection: diagonal tap on the ball
bp.setMode('lqr'); bp.setRef('point', [0 0]); bp.setInitialState(zeros(8, 1));
tp = [0 1 1.001 1.05 1.051 4]';
bp.setDisturbanceSignal(tp, [0 0; 0 0; 0.2 0.2; 0.2 0.2; 0 0; 0 0]);  % 0.28 N for 50 ms
res = bp.run(4);
bp_plot_results(res, 'LQR: diagonal tap at t = 1 s');
bp.clearSignals();

%% 7) Mode 'plate': tilt the plate by hand and watch the ball roll
bp.setMode('plate'); bp.setPlateAngle(deg2rad(-1), deg2rad(0.5));
bp.setInitialState(zeros(8, 1));
res = bp.run(4);
bp_plot_results(res, 'Plate tilted by hand: the ball rolls to the rim');
bp.animate(res);
bp.setPlateAngle(0, 0);

%% 8) Axis coupling: a large diagonal circle vs the decoupled linear design
bp.setMode('lqr'); bp.setInitialState([0.09 0 0 0 0 0 0 0]);
bp.setRef('circle', [0 0], 0.09, 0.4);
res = bp.run(12);
bp_plot_results(res, 'LQR: large fast circle (nonlinear coupling becomes visible)');

%% 9) Live mode from code (no GUI): commands while simulating
bp.setInitialState([0.08 0 -0.05 0 0 0 0 0]); bp.setMode('lqr'); bp.setRef('point', [0 0]);
bp.addTelemetryCallback(@(t, d) fprintf('t=%5.2f  ball=(%+5.1f, %+5.1f) cm\n', ...
    t, 100*d(1), 100*d(3)));
bp.TelemetryRate = 2;                 % 2 lines per second
bp.start();  pause(3)
bp.setRef('circle', [0 0], 0.06, 0.2);  pause(6)
bp.push([0 0.3], 0.05);                 pause(3)
bp.stop();   bp.clearCallbacks(); bp.TelemetryRate = 30;
res = bp.lastResult(); bp_plot_results(res, 'Live session from code');

%% 10) Live graphical interface
bp_gui(bp);
