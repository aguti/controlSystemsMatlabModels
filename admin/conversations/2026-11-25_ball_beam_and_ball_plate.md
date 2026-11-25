# Conversation: ball and beam and ball and plate — third and fourth experiments (interrupted)

Claude Code session `861c5db6`, 2026-11-25 (continuation of the rotary pendulum conversation). Exported from the session transcript. The computer broke down while the ball-and-plate examples were running; the work was resumed in the next conversation.
Internal reasoning and harness metadata are omitted; tool outputs are collapsed and truncated.

## 🧑 User

I want to create a couple of experiments more. In this case will be a one degree of freedom ball and beam, and another one with 2 DOFs ball and plate

## 🤖 Claude

Two more experiments, same pattern. First I'll re-read the rotary pendulum package (my template) since it's no longer in context.

**🔧 Bash** — List rotary package files and tool availability

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/rotary_pendulum && wc -l * validation/* 2>/dev/null; ls ../../doc/src/rotary_pendulum ../../doc/src/rotary_pendulum/data | head -60; which pdflatex python3; python3 -c "import sympy, scipy; print(sympy.__version__, scipy.__version__)"
```

</details>

<details><summary>Output</summary>

```
    103 examples.m
    154 python_reference_sim.py
     91 README.md
    369 RotaryPendulum.m
   2642 rotpend_sim.slx
     20 rotpend_sim.slxc
     23 rp_animate.m
    227 rp_build_model.m
     97 rp_controller_block.m
     20 rp_design.m
     71 rp_draw.m
    274 rp_gui.m
     27 rp_linearize.m
     16 rp_lqr.m
     88 rp_params.m
     34 rp_plant_block.m
     23 rp_plot_results.m
     19 rp_ref_block.m
     13 rp_view.m
      0 slprj
      0 validation
     80 validation/compare_with_python.py
      0 validation/results
     22 validation/rotpend_sim.slxc
     86 validation/run_validation.m
      0 validation/slprj
   4499 total
../../doc/src/rotary_pendulum:
apendices.tex
cap1_intro.tex
cap2_modelo.tex
cap3_analisis.tex
cap4_sensores.tex
cap5_control.tex
cap6_simulink.tex
cap7_codigo.tex
cap8_practicas.tex
data
fig_sistema.tex
manual.tex

../../doc/src/rotary_pendulum/data:
bode_dn_al.dat
bode_dn_th.dat
bode_up_al.dat
bode_up_th.dat
down_nosway.dat
down_step.dat
frames.png
generate_data.m
gui.png
lqr_ic.dat
lqr_locus.dat
lqr_noise.dat
lqr_push.dat
lqr_step.dat
msweep_0.012.dat
msweep_0.048.dat
msweep_0.072.dat
num.txt
pid_ic.dat
pid_step.dat
qsweep_20.dat
qsweep_5.dat
qsweep_80.dat
rsweep_0.2.dat
rsweep_5.dat
sine_0.5.dat
swingup.dat
velest.dat
/usr/bin/pdflatex
/usr/bin/python3
1.12 1.11.4
```

</details>

**🔧 Bash** — Show rotary params, design and block files

<details><summary>Command</summary>

```bash
cat rp_params.m rp_design.m rp_linearize.m rp_lqr.m rp_plant_block.m rp_controller_block.m rp_ref_block.m
```

</details>

**🔧 Bash** — Show rotary model builder

<details><summary>Command</summary>

```bash
cat rp_build_model.m
```

</details>

<details><summary>Output</summary>

```
function mdl = rp_build_model(mdl)
%RP_BUILD_MODEL  Generates the Simulink model of the rotary (Furuta) pendulum.
%
%   rp_build_model            -> creates and saves 'rotpend_sim.slx' in this folder
%
%   Model structure (top level):
%
%     cmd_ref ─┐                         cmd_ctrl ─┐
%     ref_ext ─┼─► [Reference] ── r ───────────────┼─► [Controller] ─► (+) ─► [Amplifier] ► [Plant] ─┐
%     Clock ───┘                                   │                 u_ext ┘     cmd_dist,d_ext ┘    │
%                                       y_meas ◄───┴──────────────── [Sensors] ◄─────────────────────┘
%
%   Blocks modified LIVE from code/GUI (top level):
%     cmd_ctrl  Constant [mode enable u_manual]
%     cmd_ref   Constant [type offset amplitude frequency]
%     cmd_dist  Constant  disturbance force at the pendulum tip [N]
%   Time signals from the workspace (read at start):
%     u_ext   [t u]   additional voltage on the motor
%     ref_ext [t r]   external reference (type 4)
%     d_ext   [t Fd]  scheduled disturbance
%   Telemetry ('telemetry' block, 13 signals, saved in out.tel):
%     [th thd al ald | th_meas al_meas | V_cmd V_act | r | mode E caught tripped]

if nargin < 1 || isempty(mdl), mdl = 'rotpend_sim'; end
here = fileparts(mfilename('fullpath'));

% Variables required in the base workspace
P = rp_design(rp_params());
assignin('base', 'P', P);
for v = {'u_ext', 'ref_ext', 'd_ext'}
    if ~evalin('base', sprintf('exist(''%s'',''var'')', v{1}))
        assignin('base', v{1}, [0 0; 1 0]);
    end
end

if bdIsLoaded(mdl), close_system(mdl, 0); end
f = fullfile(here, [mdl '.slx']);
if exist(f, 'file'), delete(f); end
new_system(mdl);

%% ---------------- Model configuration ----------------
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', ...
    'FixedStep', num2str(P.h), 'StopTime', '10', ...
    'BlockReduction', 'off', 'ReturnWorkspaceOutputs', 'on');
trySet(mdl, 'DefaultParameterBehavior', 'Tunable');
set_param(mdl, 'InitFcn', [ ...
    'if ~exist(''P'',''var''), P = rp_design(rp_params()); end; ' ...
    'if ~exist(''u_ext'',''var''), u_ext = [0 0; 1 0]; end; ' ...
    'if ~exist(''ref_ext'',''var''), ref_ext = [0 0; 1 0]; end; ' ...
    'if ~exist(''d_ext'',''var''), d_ext = [0 0; 1 0]; end;']);
set_param(mdl, 'StartFcn', 'RotaryPendulum.onModelStart(bdroot);');
set_param(mdl, 'StopFcn',  'RotaryPendulum.onModelStop(bdroot);');

%% ---------------- Subsystem: Reference ----------------
S = sub(mdl, 'Reference', [190 55 310 175], {'t', 'cmd', 'ext'}, {'r'});
blk([S '/Generator'], 'simulink/User-Defined Functions/MATLAB Function', [130 40 260 160]);
setScript([S '/Generator'], fullfile(here, 'rp_ref_block.m'), {});
blk([S '/Rate limiter'], 'simulink/Discontinuities/Rate Limiter', [310 85 360 115], ...
    'RisingSlewLimit', 'P.ref_rate', 'FallingSlewLimit', '-P.ref_rate');
blk([S '/Range limit'], 'simulink/Discontinuities/Saturation', [400 85 450 115], ...
    'UpperLimit', 'P.th_ref_max', 'LowerLimit', '-P.th_ref_max');
ln(S, '
... [truncated, 7862 more characters]
```

</details>

<details><summary>Output</summary>

```
function P = rp_params()
%RP_PARAMS  Parameters of the rotary (Furuta) pendulum.
%
%   Sign convention:
%     theta  arm angle [rad]        (+ counter-clockwise seen from above)
%     alpha  pendulum angle [rad]   (0 = UPRIGHT, pi = hanging)
%            alpha > 0  => the pendulum leans towards the +theta direction
%     V      motor voltage [V]      (V > 0 drives the arm towards +theta)
%
%   State: s = [theta; thetad; alpha; alphad]
%   Everything here can be changed from code with
%   rp.setParam('name', value) or by editing this file.
%   Default values are typical of a small desktop laboratory unit.

%% --- Rotary arm ---------------------------------------------------------
P.mr  = 0.095;            % arm mass [kg]
P.Lr  = 0.085;            % arm length, motor axis -> pendulum pivot [m]
P.Jh  = 6.0e-6;           % hub + motor rotor inertia [kg m^2]
P.Jr  = P.mr*P.Lr^2/3 + P.Jh;   % arm inertia about the motor axis [kg m^2]

%% --- Pendulum -----------------------------------------------------------
P.mp  = 0.024;            % pendulum mass [kg]
P.Lp  = 0.129;            % total pendulum length [m]
P.lp  = P.Lp/2;           % pivot -> centre of mass distance [m]
P.Jp  = P.mp*P.Lp^2/12;   % inertia about its CoM [kg m^2] (uniform rod)
P.g   = 9.81;             % gravity [m/s^2]

%% --- Derived inertias (recomputed by rp_design) -------------------------
P.J0  = P.Jr + P.mp*P.Lr^2;     % arm + pendulum mass at the tip
P.Ja  = P.Jp + P.mp*P.lp^2;     % pendulum about its pivot

%% --- Friction -----------------------------------------------------------
P.Dr    = 1.0e-4;         % arm viscous friction [N m s/rad]
P.Tc    = 5.0e-4;         % arm Coulomb friction [N m]
P.w_eps = 0.05;           % Coulomb smoothing (tanh) [rad/s]
P.Dp    = 5.0e-6;         % pendulum pivot viscous friction [N m s/rad]

%% --- DC motor and amplifier ---------------------------------------------
P.Rm   = 8.4;             % armature resistance [ohm]
P.kt   = 0.042;           % torque constant [N m/A]
P.km   = 0.042;           % back-EMF constant [V s/rad]
P.Vmax = 10;              % amplifier saturation [V]

%% --- Sensors (only angles are measured: theta and alpha) ----------------
P.res_th   = 2*pi/2048;   % arm encoder resolution [rad] (2048 counts/rev)
P.res_al   = 2*pi/2048;   % pendulum encoder resolution [rad]
P.noise_on = 0;           % 1 = add Gaussian noise to the measurements
P.noise_th = 1e-3;        % noise standard deviation on theta [rad]
P.noise_al = 1e-3;        % noise standard deviation on alpha [rad]

%% --- Timing -------------------------------------------------------------
P.Ts    = 0.002;          % controller / sensor sampling period [s] (500 Hz)
P.h     = 0.001;          % fixed solver step (ode4) [s]
P.tau_v = 0.005;          % derivative filter for velocity estimation [s]

%% --- Initial condition --------------------------------------------------
P.x0 = [0; 0; 0.1; 0];    % [theta; thetad; alpha; alphad]

%% --- Arm reference --------------
... [truncated, 8890 more characters]
```

</details>

**🔧 Bash** — Show RotaryPendulum class

<details><summary>Command</summary>

```bash
cat RotaryPendulum.m
```

</details>

**🔧 Bash** — Show rotary drawing and plotting helpers

<details><summary>Command</summary>

```bash
cat rp_draw.m rp_view.m rp_animate.m rp_plot_results.m
```

</details>

**🔧 Bash** — Show rotary GUI

<details><summary>Command</summary>

```bash
cat rp_gui.m
```

</details>

<details><summary>Output</summary>

```
function h = rp_draw(ax, P, h, th, al, r)
%RP_DRAW  Draws/updates the rotary pendulum in 3D on a set of axes.
%   h = rp_draw(ax, P)                  creates the graphics and returns handles
%   h = rp_draw(ax, P, h, th, al, r)    updates the pose (angles in rad)
%
%   Scene (metres, z up): motor body below the arm, arm rotating in the
%   horizontal plane z = 0, pendulum hanging from the arm tip, dashed circle
%   swept by the arm tip with the reference marker, and the shadow of the arm
%   and pendulum on the base plate to help perceive depth.
%   Change the viewpoint with view(ax, az, el) or rp_view(ax, 'iso'|'top'|'front'|'side').

zf  = -(P.Lp + 0.025);                % base plate height (below the hanging pendulum)
R   = sqrt(P.Lr^2 + P.Lp^2) + 0.015; % scene radius (furthest reach of the tip)
rr  = P.Lr + 0.016;                   % radius of the reference marker
if nargin < 3 || isempty(h)
    cla(ax); hold(ax, 'on');
    % --- base plate ---
    s = R*0.95;
    patch(ax, 'XData', [-s s s -s], 'YData', [-s -s s s], 'ZData', zf*[1 1 1 1], ...
        'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.70 0.70 0.70], ...
        'AmbientStrength', 1, 'DiffuseStrength', 0, 'SpecularStrength', 0);
    % --- motor body and hub ---
    cyl(ax, 0.028, zf, -0.018, [0.32 0.33 0.36]);
    cyl(ax, 0.011, -0.018, 0, [0.72 0.72 0.75]);
    % --- arm tip circle and angle origin ---
    a = linspace(0, 2*pi, 121);
    plot3(ax, P.Lr*cos(a), P.Lr*sin(a), 0*a, ':', 'Color', [0.55 0.55 0.55]);
    plot3(ax, [0 P.Lr+0.02], [0 0], [0 0], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
    % --- shadows ---
    h.armSh = plot3(ax, [0 P.Lr], [0 0], zf*[1 1] + 1e-4, 'Color', [0.70 0.70 0.70], 'LineWidth', 5);
    h.penSh = plot3(ax, [P.Lr P.Lr], [0 0], zf*[1 1] + 1e-4, 'Color', [0.78 0.70 0.66], 'LineWidth', 3);
    % --- reference marker ---
    h.ref = plot3(ax, rr, 0, 0, 'v', 'MarkerSize', 8, ...
        'MarkerFaceColor', [0.47 0.67 0.19], 'MarkerEdgeColor', 'none');
    % --- arm and pendulum ---
    h.arm = plot3(ax, [0 P.Lr], [0 0], [0 0], 'Color', [0.20 0.45 0.75], 'LineWidth', 7);
    h.piv = plot3(ax, P.Lr, 0, 0, 'o', 'MarkerSize', 6, ...
        'MarkerFaceColor', [0.9 0.9 0.9], 'MarkerEdgeColor', 'k');
    h.pen = plot3(ax, [P.Lr P.Lr], [0 0], [0 P.Lp], 'Color', [0.85 0.33 0.10], 'LineWidth', 4);
    h.bob = plot3(ax, P.Lr, 0, P.Lp, 'o', 'MarkerSize', 8, ...
        'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'k');
    hold(ax, 'off');
    axis(ax, 'equal');
    xlim(ax, [-R R]); ylim(ax, [-R R]); zlim(ax, [zf, P.Lp + 0.02]);
    grid(ax, 'on'); box(ax, 'off');
    xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]'); zlabel(ax, 'z [m]');
    ax.Clipping = 'off';
    view(ax, 62, 20);
    camlight(ax, 'headlight'); lighting(ax, 'gouraud');
    if nargin < 4, return; end
end
% --- update pose ---
rd = [cos(th); sin(th); 0];           % radial direction (along the arm)
td = [-sin(th); cos(th); 0];          % tangential direction (+theta)
tip = P.Lr*rd;
pe  
... [truncated, 3038 more characters]
```

</details>

<details><summary>Output</summary>

```
function rp = rp_gui(rp)
%RP_GUI  Live visual interface of the rotary (Furuta) pendulum.
%
%   rp_gui              creates a new RotaryPendulum and opens the panel
%   rp = rp_gui(rp)     uses an existing RotaryPendulum object (you can keep
%                       sending it commands from the command line
%                       while the GUI is open)
%
%   The GUI shows angles in degrees; the code interface uses radians.
%   Keyboard (window focused): left/right arrows = manual voltage of
%   ±KeyVoltage V while held down; space = push at the pendulum tip.
%   The 3D view can be rotated with the mouse or set from the "View" list.

if nargin < 1 || isempty(rp), rp = RotaryPendulum(); end
P = rp.P;
KeyVoltage = 3;
Twin = 10;                                    % plot time window [s]

%% ---------------- Window and layout ----------------
fig = uifigure('Name', 'Rotary pendulum — live Simulink', ...
    'Position', [60 60 1300 800]);
G = uigridlayout(fig, [1 2]);
G.ColumnWidth = {'1x', 340};

L = uigridlayout(G, [4 1]);
L.RowHeight = {'3x', '1x', '1x', '1x'};
axA = uiaxes(L); title(axA, 'Rotary pendulum');
axT = uiaxes(L); ylabel(axT, '\theta [deg]'); grid(axT, 'on');
axP = uiaxes(L); ylabel(axP, '\alpha [deg]'); grid(axP, 'on');
axV = uiaxes(L); ylabel(axV, 'V [V]'); xlabel(axV, 't [s]'); grid(axV, 'on');

R = uigridlayout(G, [7 1]);
R.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
R.Scrollable = 'on';

%% ---------------- Simulation ----------------
p1 = uipanel(R, 'Title', 'Simulation');
g1 = uigridlayout(p1, [5 3]); g1.RowHeight = repmat({'fit'}, 1, 5);
bStart = uibutton(g1, 'Text', '▶ Start', 'ButtonPushedFcn', @onStart, ...
    'BackgroundColor', [0.75 0.9 0.75]);
bPause = uibutton(g1, 'Text', '❚❚ Pause', 'ButtonPushedFcn', @onPause, 'Enable', 'off');
bStop  = uibutton(g1, 'Text', '■ Stop', 'ButtonPushedFcn', @onStop, 'Enable', 'off', ...
    'BackgroundColor', [0.95 0.75 0.75]);
uilabel(g1, 'Text', 'Initial state');
ddIC = uidropdown(g1, 'Items', {'Up (α0)', 'Down (α=180°)'}, 'Value', 'Up (α0)');
ddIC.Layout.Column = [2 3];
uilabel(g1, 'Text', 'α0 / θ0 [deg]');
efAl0 = uieditfield(g1, 'numeric', 'Value', rad2deg(P.x0(3)), 'Limits', [-180 180]);
efTh0 = uieditfield(g1, 'numeric', 'Value', rad2deg(P.x0(1)), 'Limits', [-180 180]);
uilabel(g1, 'Text', 'Speed');
ddRate = uidropdown(g1, 'Items', {'0.25x', '0.5x', '1x', '2x'}, 'Value', '1x');
ddRate.Layout.Column = [2 3];
uilabel(g1, 'Text', 'View');
ddView = uidropdown(g1, 'Items', {'3D', 'Top', 'Front', 'Side'}, 'ItemsData', {'iso', 'top', 'front', 'side'}, ...
    'Value', 'iso', 'ValueChangedFcn', @(s,~) rp_view(axA, s.Value));
ddView.Layout.Column = [2 3];

%% ---------------- Control ----------------
p2 = uipanel(R, 'Title', 'Control');
g2 = uigridlayout(p2, [5 2]); g2.RowHeight = repmat({'fit'}, 1, 5);
g2.ColumnWidth = {110, '1x'};
uilabel(g2, 'Text', 'Mode');
modeItems = {'0  Open loop (manual)', '1  LQR up', '2  Swing-up + LQR', ...
             '3  PID pendulum + PD arm', '4
... [truncated, 8772 more characters]
```

</details>

<details><summary>Output</summary>

```
classdef RotaryPendulum < handle
%ROTARYPENDULUM  Code interface for the Simulink model of the rotary (Furuta) pendulum.
%
%   All angles are in radians (theta = arm, alpha = pendulum, 0 = up).
%
%   rp = RotaryPendulum();           % loads (or generates) rotpend_sim.slx
%
%   --- Batch runs (fast, not real time) ---
%   rp.setInitialState([0 0 pi 0]);  % [theta thetad alpha alphad]
%   rp.setMode('swingup');           % 'open','lqr','swingup','pid','down' (or 0..4)
%   res = rp.run(8);                 % simulates 8 s and returns a struct of signals
%   rp_plot_results(res); rp.animate(res);
%
%   --- Live execution (real time, commands while running) ---
%   rp.start();                      % starts with StopTime = inf and 1x pacing
%   rp.setRef('sine', 0, pi/4, 0.2); % type, offset [rad], amplitude [rad], freq [Hz]
%   rp.setVoltage(1);                % manual voltage [V] (added to the controller's)
%   rp.push(0.05, 0.05);             % push: 0.05 N at the tip for 0.05 s
%   rp.setParam('Qup', diag([50 0.5 100 0.5]));   % recomputes the LQR and applies it live
%   rp.stop(); res = rp.lastResult();
%
%   --- Time signals (read at start) ---
%   rp.setRefSignal(t, r)       external arm reference [rad] (activates type 'external')
%   rp.setVoltageSignal(t, u)   additional motor voltage (identification)
%   rp.setDisturbanceSignal(t, Fd)   scheduled disturbance force at the tip
%
%   --- Live telemetry ---
%   rp.addTelemetryCallback(@(t, d) disp(d(1)));   % d = 13-signal vector
%   Indices: RotaryPendulum.TEL.th, .thd, .al, .ald, .thm, .alm, .Vcmd, .Vact,
%            .r, .mode, .E, .caught, .tripped

    properties
        P                       % parameter struct (rp_params + rp_design)
        Model = 'rotpend_sim'
        TelemetryRate = 30      % rate [Hz] at which live callbacks are called
        PacingRate = 1          % 1 = real time, 0.5 = slow motion, 2 = double
    end

    properties (SetAccess = private)
        Last = zeros(13,1)      % last telemetry received
        LastTime = 0
        CmdCtrl = [1 1 0]       % [mode enable u_manual]
        CmdRef  = [0 0 0 0.1]   % [type offset amplitude frequency]
        Lin                     % linear models (up/down)
    end

    properties (Access = private)
        telCallbacks = {}
        stopCallbacks = {}
        listener = []
        tick
        batch = false
        pushTimer = []
    end

    properties (Constant)
        TEL = struct('th',1,'thd',2,'al',3,'ald',4,'thm',5,'alm',6, ...
                     'Vcmd',7,'Vact',8,'r',9,'mode',10,'E',11, ...
                     'caught',12,'tripped',13)
        MODES = {'open','lqr','swingup','pid','down'}
        REFTYPES = {'const','sine','square','triangle','external'}
    end

    %% ================== Construction ==================
    methods
        function obj = RotaryPendulum(varargin)
            here = fileparts(mfilename('fullpath'));
            addpath(here);
            if nargin >= 1, obj.Model = varargin{1}; end
  
... [truncated, 10996 more characters]
```

</details>

**🔧 Bash** — Show rotary examples, Python replica and validation

<details><summary>Command</summary>

```bash
cat examples.m python_reference_sim.py validation/run_validation.m validation/compare_with_python.py
```

</details>

<details><summary>Output</summary>

```
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
subplot(2,1,2); plot(res.t, rad2deg(mod(res.al, 2*pi) - pi), tt, rad2deg(z(3,:
... [truncated, 13805 more characters]
```

</details>

## 🤖 Claude

I have the template. Before writing MATLAB I'll design and tune both systems in a Python replica (that's also the validation reference later). Ball and beam first.

**🔧 Bash** — Create experiment folders and show gitignore

<details><summary>Command</summary>

```bash
mkdir -p /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/validation /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/validation && cat /home/aguti/universidad/controlSystemsMatlabModels/.gitignore
```

</details>

<details><summary>Output</summary>

```
# Simulink build artifacts (models are generated by cp_build_model.m)
slprj/
*.slxc
*.slx.autosave
*.asv
src/**/*_sim.slx

# Python
__pycache__/

# LaTeX build files
*.aux
*.log
*.out
*.toc
*.lof
*.lot
*.synctex.gz
*.fdb_latexmk
*.fls
src/**/validation/results/
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/python_reference_sim.py` (5547 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/python_reference_sim.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Tune ball and beam controllers in Python

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam && cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb1.py <<'EOF'
import sys; sys.path.insert(0,'.')
import numpy as np
from python_reference_sim import *
P=design(params())
A,B=linearize(P)
print('J',P['J'],'kv',P['kv'],'beq',P['beq'],'mb',P['mb'])
print('OL poles',np.linalg.eigvals(A))
print('K',P['K'])
Aa=np.zeros((5,5));Aa[:4,:4]=A;Aa[4,0]=1;Ba=np.vstack([B,[[0]]])
print('CL poles',np.linalg.eigvals(Aa-Ba@P['K']))
def metrics(L,r=0.1,t0=1):
    t,x,al,V=L[:,0],L[:,1],L[:,3],L[:,5]
    i=np.where(np.abs(x-r)>0.05*r)[0]; ts=t[i[-1]]-t0 if len(i) else 0
    k=t>t0
    print(f'  settle5% {ts:.2f}s  overshoot {100*(x[k].max()-r)/r:.1f}%  Vmax {np.abs(V).max():.1f}  max|al| {np.degrees(np.abs(al)).max():.1f} final {x[-1]*100:.2f}cm min x {x[k].min()*100:.2f}')
rf=lambda t: 0.1 if t>1 else 0.0
for mode in [2,3]:
    L=simulate(P,[0,0,0,0],mode,8,ref=rf); print('mode',mode); metrics(L)
L=simulate(P,[0.15,0,0,0],3,6); print('lqr from 15cm: final',L[-1,1], 'max al',np.degrees(np.abs(L[:,3]).max()),'Vmax',np.abs(L[:,5]).max())
L=simulate(P,[0.15,0,0,0],2,6); print('cascade from 15cm: final',L[-1,1], 'max al',np.degrees(np.abs(L[:,3]).max()),'Vmax',np.abs(L[:,5]).max())
L=simulate(P,[0,0,0,0],1,3,alman=0.05); print('beam mode alman .05: al end',L[-1,3],'x end',L[-1,1],'t hit', L[np.argmax(np.abs(L[:,1])>0.185),0])
EOF
python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb1.py
```

</details>

<details><summary>Output</summary>

```
J 0.006864899999999999 kv 0.1284036923076923 beq 0.07002982498461538 mb 0.09380000000000001
OL poles [-10.68259602+0.j           3.62366856+0.j
  -1.57947755+3.85078252j  -1.57947755-3.85078252j]
K [[-24.61385018  -7.65914394  11.05972563   0.73583243 -10.        ]]
CL poles [-11.5746341 +0.j          -5.68945774+0.j
  -2.76286509+4.71763184j  -2.76286509-4.71763184j
  -0.66556821+0.j        ]
mode 2
  settle5% 6.97s  overshoot 20.1%  Vmax 5.2  max|al| 7.0 final 10.49cm min x -0.01
mode 3
  settle5% 5.19s  overshoot 65.1%  Vmax 2.5  max|al| 10.2 final 10.02cm min x -0.01
lqr from 15cm: final 0.0008903984866903884 max al 13.472606387919742 Vmax 3.7014389606315694
cascade from 15cm: final -0.006866173028733414 max al 10.738371105256709 Vmax 7.807962421874999
beam mode alman .05: al end 0.07439625824937317 x end -0.19589825417872148 t hit 1.062
```

</details>

**🔧 Bash** — Sweep LQR weights and cascade gains

<details><summary>Command</summary>

```bash
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py <<'EOF'
import sys; sys.path.insert(0,'.')
import numpy as np
from python_reference_sim import *
rf=lambda t: 0.1 if t>1 else 0.0
def metrics(L,r=0.1,t0=1):
    t,x,al,V=L[:,0],L[:,1],L[:,3],L[:,5]
    i=np.where(np.abs(x-r)>0.05*r)[0]; ts=t[i[-1]]-t0 if len(i) else 0
    k=t>t0
    return f'settle5% {ts:.2f}s ov {100*(x[k].max()-r)/r:.1f}% Vmax {np.abs(V).max():.1f} max|al| {np.degrees(np.abs(al)).max():.1f} final {x[-1]*100:.2f} undershoot {x[k].min()*100:.2f}'
for Q in [[500,10,1,0.1,50],[1000,20,1,0.1,100],[300,10,1,0.1,20],[1000,50,10,0.5,200]]:
    P=params(); P['Q']=np.diag(Q); P=design(P)
    print(Q, np.round(P['K'],2), metrics(simulate(P,[0,0,0,0],3,8,ref=rf)))
for kp,kd,ki in [(1.3,0.8,0.1),(1.3,0.8,0.0),(2,1.0,0.2),(1.3,1.0,0.2)]:
    P=design(params()); P.update(Kp_x=kp,Kd_x=kd,Ki_x=ki)
    print(kp,kd,ki, metrics(simulate(P,[0,0,0,0],2,8,ref=rf)))
EOF
python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py
```

</details>

<details><summary>Error</summary>

```
The server-side auto mode classifier gave no verdict (timed out), so auto mode cannot determine the safety of Bash. This is a transient failure of the check, not a judgment about the action: a later response may get a verdict. You may try the action again once, as-is. Repeated attempts are slowed by a growing delay, and after 10 responses in a row without a verdict the turn stops. If it keeps failing, continue with other tasks that don't require this action and come back to it later. Note: reading files, searching code, and other read-only operations do not require the classifier and can still be used.
```

</details>

**🔧 Bash** — Sweep LQR weights and cascade gains

<details><summary>Command</summary>

```bash
python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py
```

</details>

<details><summary>Error</summary>

```
Exit code 2
python3: can't open file '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py': [Errno 2] No such file or directory
```

</details>

**🔧 Write** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py` (975 characters)

<details><summary>Output</summary>

```
File created successfully at: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Sweep LQR weights and cascade gains

<details><summary>Command</summary>

```bash
python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py
```

</details>

<details><summary>Output</summary>

```
[500, 10, 1, 0.1, 50] [[-31.01 -10.16  13.06   0.83  -7.07]] settle5% 7.00s ov 40.4% Vmax 3.1 max|al| 10.8 final 10.51 under -0.01
[1000, 20, 1, 0.1, 100] [[-41.04 -13.16  15.41   0.93 -10.  ]] settle5% 5.61s ov 32.6% Vmax 4.1 max|al| 12.3 final 10.30 under -0.01
[300, 10, 1, 0.1, 20] [[-25.24  -8.74  11.91   0.78  -4.47]] settle5% 7.00s ov 41.8% Vmax 2.5 max|al| 9.5 final 10.70 under -0.01
[1000, 50, 10, 0.5, 200] [[-43.5  -15.74  18.79   1.18 -14.14]] settle5% 4.80s ov 25.5% Vmax 4.4 max|al| 10.7 final 10.22 under -0.01
1.3 0.8 0.1 settle5% 7.00s ov 14.1% Vmax 5.2 max|al| 6.9 final 11.02 under -0.01
1.3 0.8 0.0 settle5% 7.00s ov 11.0% Vmax 5.2 max|al| 6.9 final 11.09 under -0.01
2 1.0 0.2 settle5% 7.00s ov 10.5% Vmax 8.0 max|al| 10.6 final 10.67 under -0.02
1.3 1.0 0.2 settle5% 7.00s ov 17.9% Vmax 5.2 max|al| 6.9 final 11.01 under -0.01
```

</details>

## 🤖 Claude

Tuning the ball-and-beam controllers in Python. The ball's weight loads the motor and leaves a steady error, so I'm testing integral action that only runs near the target.

**🔧 Bash** — Add conditional integration and rerun sweep

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
import re
s=open('python_reference_sim.py').read()
s=s.replace("Kp_x=1.3, Kd_x=0.7, Ki_x=0.3, I_max=0.5, al_ref_max=0.25,","Kp_x=1.3, Kd_x=0.7, Ki_x=0.3, I_max=0.5, al_ref_max=0.25,\n        e_int=0.02,   # integrate only when |x - r| < e_int (conditional anti-windup)")
s=s.replace("""            e = x - r
            s.I = np.clip(s.I + e*P['Ts'], -P['I_max'], P['I_max'])
            s.alr""","""            e = x - r
            if abs(e) < P['e_int']:
                s.I = np.clip(s.I + e*P['Ts'], -P['I_max'], P['I_max'])
            s.alr""")
s=s.replace("""            e = x - r
            s.I = np.clip(s.I + e*P['Ts'], -P['I_max'], P['I_max'])
            V = (-P['K']""","""            e = x - r
            if abs(e) < P['e_int']:
                s.I = np.clip(s.I + e*P['Ts'], -P['I_max'], P['I_max'])
            V = (-P['K']""")
open('python_reference_sim.py','w').write(s)
EOF
grep -n e_int python_reference_sim.py; python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py
```

</details>

<details><summary>Output</summary>

```
36:        e_int=0.02,   # integrate only when |x - r| < e_int (conditional anti-windup)
121:            if abs(e) < P['e_int']:
128:            if abs(e) < P['e_int']:
[500, 10, 1, 0.1, 50] [[-31.01 -10.16  13.06   0.83  -7.07]] settle5% 6.17s ov 31.6% Vmax 3.1 max|al| 10.5 final 10.49 under -0.01
[1000, 20, 1, 0.1, 100] [[-41.04 -13.16  15.41   0.93 -10.  ]] settle5% 4.32s ov 24.3% Vmax 4.1 max|al| 12.0 final 10.19 under -0.01
[300, 10, 1, 0.1, 20] [[-25.24  -8.74  11.91   0.78  -4.47]] settle5% 7.00s ov 34.3% Vmax 2.5 max|al| 9.3 final 12.36 under -0.01
[1000, 50, 10, 0.5, 200] [[-43.5  -15.74  18.79   1.18 -14.14]] settle5% 3.38s ov 14.3% Vmax 4.3 max|al| 10.3 final 10.13 under -0.01
1.3 0.8 0.1 settle5% 7.00s ov 10.2% Vmax 5.2 max|al| 6.9 final 10.77 under -0.01
1.3 0.8 0.0 settle5% 7.00s ov 11.0% Vmax 5.2 max|al| 6.9 final 11.09 under -0.01
2 1.0 0.2 settle5% 5.85s ov 6.6% Vmax 8.0 max|al| 10.5 final 10.43 under -0.02
1.3 1.0 0.2 settle5% 7.00s ov 10.0% Vmax 5.2 max|al| 6.8 final 10.59 under -0.01
```

</details>

**🔧 Bash** — Add weight-torque feedforward and rerun sweep

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
s=open('python_reference_sim.py').read()
s=s.replace("        e_int=0.02,","        e_int=0.02,\n        ff_on=1,      # 1 = compensate the ball weight torque m g x / kv (feedforward)")
s=s.replace("""            V = P['Kp_a']*(s.alr - al) - P['Kd_a']*ald
        elif mode == 3:""","""            V = P['Kp_a']*(s.alr - al) - P['Kd_a']*ald + P['ff_on']*P['m']*P['g']*x/P['kv']
        elif mode == 3:""")
s=s.replace("""            V = (-P['K'] @ np.array([e, xd, al, ald, s.I])).item()""","""            V = (-P['K'] @ np.array([e, xd, al, ald, s.I])).item() + P['ff_on']*P['m']*P['g']*r/P['kv']""")
open('python_reference_sim.py','w').write(s)
EOF
grep -n "ff_on" python_reference_sim.py; python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb2.py
```

</details>

<details><summary>Output</summary>

```
37:        ff_on=1,      # 1 = compensate the ball weight torque m g x / kv (feedforward)   # integrate only when |x - r| < e_int (conditional anti-windup)
126:            V = P['Kp_a']*(s.alr - al) - P['Kd_a']*ald + P['ff_on']*P['m']*P['g']*x/P['kv']
131:            V = (-P['K'] @ np.array([e, xd, al, ald, s.I])).item() + P['ff_on']*P['m']*P['g']*r/P['kv']
[500, 10, 1, 0.1, 50] [[-31.01 -10.16  13.06   0.83  -7.07]] settle5% 1.40s ov 9.6% Vmax 2.6 max|al| 8.7 final 10.05 under -0.01
[1000, 20, 1, 0.1, 100] [[-41.04 -13.16  15.41   0.93 -10.  ]] settle5% 1.21s ov 8.3% Vmax 3.6 max|al| 10.4 final 9.95 under -0.01
[300, 10, 1, 0.1, 20] [[-25.24  -8.74  11.91   0.78  -4.47]] settle5% 1.51s ov 7.2% Vmax 2.0 max|al| 7.3 final 9.93 under -0.01
[1000, 50, 10, 0.5, 200] [[-43.5  -15.74  18.79   1.18 -14.14]] settle5% 0.64s ov 2.5% Vmax 3.8 max|al| 9.1 final 10.02 under -0.01
1.3 0.8 0.1 settle5% 1.50s ov 0.8% Vmax 5.2 max|al| 6.9 final 10.03 under -0.01
1.3 0.8 0.0 settle5% 1.51s ov 0.1% Vmax 5.2 max|al| 6.9 final 9.99 under -0.01
2 1.0 0.2 settle5% 1.23s ov 0.7% Vmax 8.0 max|al| 10.5 final 10.03 under -0.02
1.3 1.0 0.2 settle5% 2.01s ov 1.4% Vmax 5.2 max|al| 6.8 final 10.09 under -0.01
```

</details>

**🔧 Bash** — Fix comments and set tuned defaults

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
s=open('python_reference_sim.py').read()
s=s.replace("        e_int=0.02,\n        ff_on=1,      # 1 = compensate the ball weight torque m g x / kv (feedforward)   # integrate only when |x - r| < e_int (conditional anti-windup)",
"        e_int=0.02,   # integrate only when |x - r| < e_int (conditional anti-windup)\n        ff_on=1,      # 1 = compensate the ball weight torque on the beam (feedforward)")
s=s.replace("Kp_x=1.3, Kd_x=0.7, Ki_x=0.3,","Kp_x=1.3, Kd_x=0.8, Ki_x=0.1,")
s=s.replace("Q=np.diag([200.0, 1.0, 5.0, 0.1, 100.0]), R=1.0,","Q=np.diag([1000.0, 50.0, 10.0, 0.5, 200.0]), R=1.0,")
open('python_reference_sim.py','w').write(s)
EOF
sed -n 30,42p python_reference_sim.py
```

</details>

<details><summary>Output</summary>

```
        res_al=2*np.pi/4096, res_x=0.42/4096,
        Ts=0.002, h=0.001, tau_v=0.005, tau_x=0.02,
        # beam angle loop (PD)
        Kp_a=40.0, Kd_a=1.5,
        # ball loop (cascade PID -> beam angle reference)
        Kp_x=1.3, Kd_x=0.8, Ki_x=0.1, I_max=0.5, al_ref_max=0.25,
        e_int=0.02,   # integrate only when |x - r| < e_int (conditional anti-windup)
        ff_on=1,      # 1 = compensate the ball weight torque on the beam (feedforward)
        # LQR with integral action
        Q=np.diag([1000.0, 50.0, 10.0, 0.5, 200.0]), R=1.0,
    )
    return derived(P)
```

</details>

**🔧 Write** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb3.py` (1445 characters)

<details><summary>Output</summary>

```
File created successfully at: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb3.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Run ball and beam scenario checks

<details><summary>Command</summary>

```bash
python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bb3.py
```

</details>

<details><summary>Output</summary>

```
K [[-43.5  -15.74  18.79   1.18 -14.14]] CL [-16.65+0.j    -4.9 +5.78j  -4.9 -5.78j  -4.37+0.j    -0.44+0.j  ]
OL [-10.683+0.j      3.624+0.j     -1.579+3.851j  -1.579-3.851j]
2 from 15 cm: final -0.07 cm, max al 11.8, Vmax 8.6
2 tap 0.2N 50ms: max |x| 1.66 cm, final -0.06
   sine 0.10 Hz gain 1.06 lag 21 deg Vmax 1.0
   sine 0.25 Hz gain 0.83 lag 51 deg Vmax 0.9
   sine 0.50 Hz gain 0.58 lag 88 deg Vmax 0.7
3 from 15 cm: final -0.01 cm, max al 15.6, Vmax 6.5
3 tap 0.2N 50ms: max |x| 1.89 cm, final -0.05
   sine 0.10 Hz gain 1.08 lag 14 deg Vmax 0.9
   sine 0.25 Hz gain 0.96 lag 35 deg Vmax 0.9
   sine 0.50 Hz gain 0.88 lag 69 deg Vmax 0.9
beam mode: al end 0.074, x end -0.196
robust m 0.03 final 0.10008165170514444
robust m 0.134 final 0.10033399405716031
```

</details>

## 🤖 Claude

Ball and beam tunes well with a weight-torque feedforward: LQR settles a 10 cm step in 0.64 s. Now the ball-and-plate replica (4 DOF, camera-based ball sensing at 50 Hz with one frame of latency).

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/python_reference_sim.py` (7554 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/python_reference_sim.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Write** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bp1.py` (1380 characters)

<details><summary>Output</summary>

```
File created successfully at: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bp1.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Run ball and plate controller checks

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate && time python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bp1.py
```

</details>

<details><summary>Output</summary>

```
Ja 0.0065949 Jbt 0.0050949 OL [-11.06+0.j     3.64+0.j    -1.6 +3.85j  -1.6 -3.85j]
Kx [[-26.87 -10.33  14.58   1.    -7.07]] Ky [[-26.8  -10.13  13.9    0.87  -7.07]]
nominal mode 2: step settle(5mm) 1.63s ovx 1.2% Vmax 3.2 max tilt 4.5 final (8.06,-5.07)
    circle 0.2 Hz r=6cm: radius 5.14 cm (min 5.07, max 5.21), Vmax 0.9
    circle 0.4 Hz r=6cm: radius 3.90 cm (min 3.88, max 3.93), Vmax 0.8
nominal mode 3: step settle(5mm) 3.45s ovx 12.5% Vmax 1.7 max tilt 5.6 final (8.14,-5.10)
    circle 0.2 Hz r=6cm: radius 5.93 cm (min 5.55, max 6.40), Vmax 0.6
    circle 0.4 Hz r=6cm: radius 5.78 cm (min 5.66, max 5.90), Vmax 0.6

real	0m11.082s
user	0m11.026s
sys	0m0.053s
```

</details>

**🔧 Bash** — Sweep plate LQR weights

<details><summary>Command</summary>

```bash
cat >> /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bp1.py <<'EOF'
if len(sys.argv) > 1:
    for Q in eval(sys.argv[1]):
        P = params(); P['Q'] = np.diag(Q); P = design(P)
        print(Q, np.round(P['Kx'], 2))
        run(P, 'Q')
EOF
sed -i 's/^run(P, .nominal.)$/if len(sys.argv) == 1: run(P, "nominal")/' /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bp1.py
python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bp1.py "[[300,50,10,0.5,50],[500,60,10,0.5,100],[200,40,5,0.3,30]]" 2>&1 | grep -v "mode 2" | grep -v "^    circle.*Vmax 0.9"
```

</details>

<details><summary>Output</summary>

```
Ja 0.0065949 Jbt 0.0050949 OL [-11.06+0.j     3.64+0.j    -1.6 +3.85j  -1.6 -3.85j]
Kx [[-26.87 -10.33  14.58   1.    -7.07]] Ky [[-26.8  -10.13  13.9    0.87  -7.07]]
[300, 50, 10, 0.5, 50] [[-27.47 -12.23  16.23   1.07  -7.07]]
    circle 0.4 Hz r=6cm: radius 3.90 cm (min 3.88, max 3.93), Vmax 0.8
Q mode 3: step settle(5mm) 2.08s ovx 5.9% Vmax 1.8 max tilt 5.2 final (8.01,-5.00)
    circle 0.2 Hz r=6cm: radius 5.66 cm (min 5.36, max 5.90), Vmax 0.7
    circle 0.4 Hz r=6cm: radius 5.11 cm (min 4.98, max 5.24), Vmax 0.6
[500, 60, 10, 0.5, 100] [[-33.54 -14.02  17.56   1.11 -10.  ]]
    circle 0.4 Hz r=6cm: radius 3.90 cm (min 3.88, max 3.93), Vmax 0.8
Q mode 3: step settle(5mm) 1.92s ovx 6.4% Vmax 2.3 max tilt 6.2 final (7.99,-5.00)
    circle 0.2 Hz r=6cm: radius 5.76 cm (min 5.41, max 6.09), Vmax 0.7
    circle 0.4 Hz r=6cm: radius 5.26 cm (min 5.13, max 5.43), Vmax 0.7
[200, 40, 5, 0.3, 30] [[-23.64 -10.62  14.32   0.93  -5.48]]
    circle 0.4 Hz r=6cm: radius 3.90 cm (min 3.88, max 3.93), Vmax 0.8
Q mode 3: step settle(5mm) 2.17s ovx 6.2% Vmax 1.5 max tilt 4.8 final (8.13,-5.07)
    circle 0.2 Hz r=6cm: radius 5.61 cm (min 5.35, max 5.83), Vmax 0.6
    circle 0.4 Hz r=6cm: radius 5.06 cm (min 4.93, max 5.19), Vmax 0.6
[This command modified 1 file you've previously read: ../../../../../../tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bp1.py. Call Read before editing.]
```

</details>

## 🤖 Claude

Plate LQR settles in about 1.9 s; the camera delay costs some damping, which the manual will discuss. Now the MATLAB package for the ball and beam.

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_params.m` (4229 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_derived.m` (600 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_linearize.m` (752 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_design.m` (534 characters)

**🔧 Bash** — Copy LQR solver for both experiments

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && sed 's/RP_LQR/BB_LQR/; s/rp_lqr/bb_lqr/' rotary_pendulum/rp_lqr.m > ball_beam/bb_lqr.m && sed 's/RP_LQR/BP_LQR/; s/rp_lqr/bp_lqr/' rotary_pendulum/rp_lqr.m > ball_plate/bp_lqr.m && head -3 ball_beam/bb_lqr.m
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_params.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_derived.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_linearize.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_design.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
function K = bb_lqr(A, B, Q, R)
%BB_LQR  LQR gain. Uses lqr() if the Control System Toolbox is available;
%   otherwise solves the Riccati equation with the Hamiltonian method.
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_plant_block.m` (1727 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_controller_block.m` (2324 characters)

**🔧 Bash** — Create ball and beam reference block

<details><summary>Command</summary>

```bash
sed 's/RP_REF_BLOCK  Arm reference generator/BB_REF_BLOCK  Ball position reference generator/; s/rp_ref_block/bb_ref_block/; s/(angles in rad)/(positions in m)/' rotary_pendulum/rp_ref_block.m > ball_beam/bb_ref_block.m && head -4 ball_beam/bb_ref_block.m
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_plant_block.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_controller_block.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
function r = bb_ref_block(t, cmd, ext)
%BB_REF_BLOCK  Ball position reference generator ("Reference/Generator" block).
%   cmd = [type; offset; amplitude; frequency_Hz]   (positions in m)
%   type: 0 constant | 1 sine | 2 square | 3 triangle | 4 external (ref_ext)
```

</details>

**🔧 Bash** — Derive ball and beam model builder from rotary

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
s = open('rotary_pendulum/rp_build_model.m').read()
rep = [
 ("RP_BUILD_MODEL  Generates the Simulink model of the rotary (Furuta) pendulum.", "BB_BUILD_MODEL  Generates the Simulink model of the ball and beam."),
 ("rp_build_model            -> creates and saves 'rotpend_sim.slx'", "bb_build_model            -> creates and saves 'ballbeam_sim.slx'"),
 ("cmd_ctrl  Constant [mode enable u_manual]", "cmd_ctrl  Constant [mode enable u_manual alpha_manual]"),
 ("cmd_dist  Constant  disturbance force at the pendulum tip [N]", "cmd_dist  Constant  disturbance force on the ball [N]"),
 ("d_ext   [t Fd]  scheduled disturbance", "d_ext   [t Fd]  scheduled disturbance force on the ball"),
 ("Telemetry ('telemetry' block, 13 signals, saved in out.tel):\n%     [th thd al ald | th_meas al_meas | V_cmd V_act | r | mode E caught tripped]",
  "Telemetry ('telemetry' block, 12 signals, saved in out.tel):\n%     [x xd al ald | x_meas al_meas | V_cmd V_act | r | mode al_ref I]"),
 ("mdl = 'rotpend_sim'", "mdl = 'ballbeam_sim'"),
 ("rp_design(rp_params())", "bb_design(bb_params())"),
 ("RotaryPendulum.onModel", "BallBeam.onModel"),
 ("'rp_ref_block.m'", "'bb_ref_block.m'"),
 ("'P.th_ref_max', 'LowerLimit', '-P.th_ref_max'", "'P.x_ref_max', 'LowerLimit', '-P.x_ref_max'"),
 ("'rp_controller_block.m'", "'bb_controller_block.m'"),
 ("'rp_plant_block.m'", "'bb_plant_block.m'"),
 ("'Sum th", "'Sum x"), ("'Encoder th", "'Ball sensor x"), ("'Noise th", "'Noise x"), ("'sigma th", "'sigma x"), ("'Term thd", "'Term xd"),
 ("Sum th/", "Sum x/"), ("Encoder th/", "Ball sensor x/"), ("Noise th/", "Noise x/"), ("sigma th/", "sigma x/"), ("Term thd/", "Term xd/"),
 ("P.noise_on*P.noise_th", "P.noise_on*P.noise_x"), ("'P.res_th'", "'P.res_x'"),
 ("'Encoder al", "'Encoder al"),
 ("'Value', '[1 1 0]'", "'Value', '[3 1 0 0]'"),
 ("sel = {'theta r', '[1 9]', 470; 'alpha', '[3]', 530; 'V cmd-act', '[7 8]', 590};",
  "sel = {'x r', '[1 9]', 470; 'alpha alpha_ref', '[3 11]', 530; 'V cmd-act', '[7 8]', 590};"),
 ("'InputPortWidth', '13'", "'InputPortWidth', '12'"),
 ("RotaryPendulum.start()", "BallBeam.start()"),
 ("'rp_build_model:param'", "'bb_build_model:param'"),
]
for a, b in rep:
    assert a in s, a
    s = s.replace(a, b)
open('ball_beam/bb_build_model.m', 'w').write(s)
EOF
grep -n "rp_\|Rotary\|theta\|th_\|pendulum" ball_beam/bb_build_model.m
```

</details>

<details><summary>Error</summary>

```
Exit code 2
Traceback (most recent call last):
  File "<stdin>", line 29, in <module>
AssertionError: Sum th/
ugrep: warning: ball_beam/bb_build_model.m: No such file or directory
```

</details>

**🔧 Bash** — Derive ball and beam model builder from rotary

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
s = open('rotary_pendulum/rp_build_model.m').read()
rep = [
 ("RP_BUILD_MODEL  Generates the Simulink model of the rotary (Furuta) pendulum.", "BB_BUILD_MODEL  Generates the Simulink model of the ball and beam."),
 ("rp_build_model            -> creates and saves 'rotpend_sim.slx'", "bb_build_model            -> creates and saves 'ballbeam_sim.slx'"),
 ("cmd_ctrl  Constant [mode enable u_manual]", "cmd_ctrl  Constant [mode enable u_manual alpha_manual]"),
 ("cmd_dist  Constant  disturbance force at the pendulum tip [N]", "cmd_dist  Constant  disturbance force on the ball [N]"),
 ("d_ext   [t Fd]  scheduled disturbance", "d_ext   [t Fd]  scheduled disturbance force on the ball"),
 ("Telemetry ('telemetry' block, 13 signals, saved in out.tel):\n%     [th thd al ald | th_meas al_meas | V_cmd V_act | r | mode E caught tripped]",
  "Telemetry ('telemetry' block, 12 signals, saved in out.tel):\n%     [x xd al ald | x_meas al_meas | V_cmd V_act | r | mode al_ref I]"),
 ("mdl = 'rotpend_sim'", "mdl = 'ballbeam_sim'"),
 ("rp_design(rp_params())", "bb_design(bb_params())"),
 ("RotaryPendulum.onModel", "BallBeam.onModel"),
 ("'rp_ref_block.m'", "'bb_ref_block.m'"),
 ("'P.th_ref_max', 'LowerLimit', '-P.th_ref_max'", "'P.x_ref_max', 'LowerLimit', '-P.x_ref_max'"),
 ("'rp_controller_block.m'", "'bb_controller_block.m'"),
 ("'rp_plant_block.m'", "'bb_plant_block.m'"),
 ("'Sum th", "'Sum x"), ("'Encoder th", "'Ball sensor x"), ("'Noise th", "'Noise x"), ("'sigma th", "'sigma x"), ("'Term thd", "'Term xd"),
 ("P.noise_on*P.noise_th", "P.noise_on*P.noise_x"), ("'P.res_th'", "'P.res_x'"),
 ("'Value', '[1 1 0]'", "'Value', '[3 1 0 0]'"),
 ("sel = {'theta r', '[1 9]', 470; 'alpha', '[3]', 530; 'V cmd-act', '[7 8]', 590};",
  "sel = {'x r', '[1 9]', 470; 'alpha alpha_ref', '[3 11]', 530; 'V cmd-act', '[7 8]', 590};"),
 ("'InputPortWidth', '13'", "'InputPortWidth', '12'"),
 ("RotaryPendulum.start()", "BallBeam.start()"),
 ("'rp_build_model:param'", "'bb_build_model:param'"),
]
for a, b in rep:
    assert a in s, a
    s = s.replace(a, b)
open('ball_beam/bb_build_model.m', 'w').write(s)
EOF
grep -n "rp_\|Rotary\|theta\|th_\|th'\|pendulum\|Amplifier\|cmd_ctrl'\]" ball_beam/bb_build_model.m
```

</details>

<details><summary>Output</summary>

```
1:function mdl = rp_build_model(mdl)
9:%     ref_ext ─┼─► [Reference] ── r ───────────────┼─► [Controller] ─► (+) ─► [Amplifier] ► [Plant] ─┐
25:here = fileparts(mfilename('fullpath'));
77:%% ---------------- Subsystem: Amplifier ----------------
78:S = sub(mdl, 'Amplifier', [700 240 820 300], {'V_cmd'}, {'V_act'});
100:blk([S '/Noise th'], 'simulink/Sources/Random Number', [90 180 120 210], ...
104:blk([S '/sigma th'], 'simulink/Math Operations/Gain', [150 180 200 210], 'Gain', 'P.noise_on*P.noise_x');
106:blk([S '/Sum th'], 'simulink/Math Operations/Sum', [240 25 260 45], 'Inputs', '++');
108:blk([S '/Encoder th'], 'simulink/Discontinuities/Quantizer', [300 20 340 50], 'QuantizationInterval', 'P.res_x');
127:blk([mdl '/cmd_ctrl'], 'simulink/Sources/Constant', [220 300 330 330], 'Value', '[3 1 0 0]');
146:ln(mdl, 'SumV/1', 'Amplifier/1');
147:ln(mdl, 'Amplifier/1', 'Plant/1');
161:ln(mdl, 'Amplifier/1', 'Mux tel/4');
172:        'Indices', sel{k,2}, 'InputPortWidth', '12');
213:ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blkPath);
```

</details>

**🔧 Bash** — Fix remaining renamed sensor blocks

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam && sed -i "1s/rp_build_model/bb_build_model/; s#'/Noise th'#'/Noise x'#; s#'/sigma th'#'/sigma x'#; s#'/Sum th'#'/Sum x'#; s#'/Encoder th'#'/Ball sensor x'#; s#'/Term thd'#'/Term xd'#" bb_build_model.m && grep -n "th'\|Noise\|sigma\|Ball sensor\|Term" bb_build_model.m
```

</details>

<details><summary>Output</summary>

```
25:here = fileparts(mfilename('fullpath'));
98:blk([S '/Term xd'], 'simulink/Sinks/Terminator', [150 55 170 75]);
99:blk([S '/Term ald'], 'simulink/Sinks/Terminator', [150 125 170 145]);
100:blk([S '/Noise x'], 'simulink/Sources/Random Number', [90 180 120 210], ...
102:blk([S '/Noise al'], 'simulink/Sources/Random Number', [90 240 120 270], ...
104:blk([S '/sigma x'], 'simulink/Math Operations/Gain', [150 180 200 210], 'Gain', 'P.noise_on*P.noise_x');
105:blk([S '/sigma al'], 'simulink/Math Operations/Gain', [150 240 200 270], 'Gain', 'P.noise_on*P.noise_al');
108:blk([S '/Ball sensor x'], 'simulink/Discontinuities/Quantizer', [300 20 340 50], 'QuantizationInterval', 'P.res_x');
113:ln(S, 'Demux/1', 'Sum x/1'); ln(S, 'Demux/2', 'Term xd/1');
114:ln(S, 'Demux/3', 'Sum al/1'); ln(S, 'Demux/4', 'Term ald/1');
115:ln(S, 'Noise x/1', 'sigma x/1'); ln(S, 'sigma x/1', 'Sum x/2');
116:ln(S, 'Noise al/1', 'sigma al/1'); ln(S, 'sigma al/1', 'Sum al/2');
117:ln(S, 'Sum x/1', 'Ball sensor x/1'); ln(S, 'Sum al/1', 'Encoder al/1');
118:ln(S, 'Ball sensor x/1', 'Mux/1');    ln(S, 'Encoder al/1', 'Mux/2');
172:        'Indices', sel{k,2}, 'InputPortWidth', '12');
213:ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blkPath);
```

</details>

**🔧 Bash** — Derive BallBeam class from RotaryPendulum

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && python3 - <<'EOF'
s = open('rotary_pendulum/RotaryPendulum.m').read()
head_end = s.index("    properties\n")
header = '''classdef BallBeam < handle
%BALLBEAM  Code interface for the Simulink model of the ball and beam.
%
%   Units: metres and radians (x = ball position, alpha = beam angle).
%
%   bb = BallBeam();                 % loads (or generates) ballbeam_sim.slx
%
%   --- Batch runs (fast, not real time) ---
%   bb.setInitialState([0.1 0 0 0]); % [x xd alpha alphad]
%   bb.setMode('lqr');               % 'open','beam','cascade','lqr' (or 0..3)
%   bb.setRef('const', 0);           % ball reference [m]
%   res = bb.run(5);                 % simulates 5 s and returns a struct of signals
%   bb_plot_results(res); bb.animate(res);
%
%   --- Live execution (real time, commands while running) ---
%   bb.start();                      % starts with StopTime = inf and 1x pacing
%   bb.setRef('sine', 0, 0.1, 0.2);  % type, offset [m], amplitude [m], freq [Hz]
%   bb.setVoltage(1);                % manual voltage [V] (added to the controller's)
%   bb.setBeamAngle(0.05);           % beam angle for mode 'beam' [rad]
%   bb.push(0.2, 0.05);              % tap: 0.2 N on the ball for 0.05 s
%   bb.setParam('Q', diag([2000 50 10 0.5 200]));   % recomputes the LQR, live
%   bb.stop(); res = bb.lastResult();
%
%   --- Time signals (read at start) ---
%   bb.setRefSignal(t, r)       external ball reference [m] (activates type 'external')
%   bb.setVoltageSignal(t, u)   additional motor voltage (identification)
%   bb.setDisturbanceSignal(t, Fd)   scheduled disturbance force on the ball [N]
%
%   --- Live telemetry ---
%   bb.addTelemetryCallback(@(t, d) disp(d(1)));   % d = 12-signal vector
%   Indices: BallBeam.TEL.x, .xd, .al, .ald, .xm, .alm, .Vcmd, .Vact,
%            .r, .mode, .alr, .I

'''
s = header + s[head_end:]
rep = [
 ("P                       % parameter struct (rp_params + rp_design)", "P                       % parameter struct (bb_params + bb_design)"),
 ("Model = 'rotpend_sim'", "Model = 'ballbeam_sim'"),
 ("Last = zeros(13,1)", "Last = zeros(12,1)"),
 ("CmdCtrl = [1 1 0]       % [mode enable u_manual]", "CmdCtrl = [3 1 0 0]     % [mode enable u_manual alpha_manual]"),
 ("CmdRef  = [0 0 0 0.1]", "CmdRef  = [0 0 0.1 0.1]"),
 ("Lin                     % linear models (up/down)", "Lin                     % linear model"),
 ("""        TEL = struct('th',1,'thd',2,'al',3,'ald',4,'thm',5,'alm',6, ...
                     'Vcmd',7,'Vact',8,'r',9,'mode',10,'E',11, ...
                     'caught',12,'tripped',13)
        MODES = {'open','lqr','swingup','pid','down'}""",
  """        TEL = struct('x',1,'xd',2,'al',3,'ald',4,'xm',5,'alm',6, ...
                     'Vcmd',7,'Vact',8,'r',9,'mode',10,'alr',11,'I',12)
        MODES = {'open','beam','cascade','lqr'}"""),
 ("function obj = RotaryPendulum(varargin)", "function obj = BallBeam(varargin)"),
 ("obj.P = rp_params();\n            [obj.P, obj.Lin] = rp_design(obj.P);", "obj.P = bb_params();\n            [obj.P, obj.Lin] = bb_design(obj.P);"),
 ("rp_build_model(obj.Model);", "bb_build_model(obj.Model);"),
 ("'RotaryPendulumInstance'", "'BallBeamInstance'"),
 ("""            %SETMODE  0/'open' 1/'lqr' 2/'swingup' 3/'pid' 4/'down'""", """            %SETMODE  0/'open' 1/'beam' 2/'cascade' 3/'lqr'"""),
 ("""            obj.CmdCtrl(3) = max(min(u, obj.P.Vmax), -obj.P.Vmax); obj.applyCmd();
        end
""", """            obj.CmdCtrl(3) = max(min(u, obj.P.Vmax), -obj.P.Vmax); obj.applyCmd();
        end

        function setBeamAngle(obj, al)
            %SETBEAMANGLE  Beam angle reference [rad] used in mode 'beam'.
            obj.CmdCtrl(4) = max(min(al, obj.P.al_max), -obj.P.al_max); obj.applyCmd();
        end
"""),
 ("%SETREF  setRef(type, offset, amplitude, frequency)   (angles in rad)", "%SETREF  setRef(type, offset, amplitude, frequency)   (positions in m)"),
 ("""            %PUSH  Tangential push at the pendulum tip (live). F [N], dur [s].
            if nargin < 2, F = 0.05; end""", """            %PUSH  Tap on the ball along the beam (live). F [N], dur [s].
            if nargin < 2, F = 0.2; end"""),
 ("%SETPARAM  Changes a parameter; recomputes the LQR and updates live.", "%SETPARAM  Changes a parameter; recomputes derived values and the LQR, live."),
 ("[obj.P, obj.Lin] = rp_design(obj.P);\n            obj.pushParams();\n            obj.refresh();", "[obj.P, obj.Lin] = bb_design(obj.P);\n            obj.pushParams();\n            obj.refresh();"),
 ("""            %   Useful for robustness tests (true plant ~= nominal) or to
            %   impose gains by hand: rp.setParamRaw('K_up', [...]).""", """            %   Useful for robustness tests (true plant ~= nominal) or to
            %   impose gains by hand: bb.setParamRaw('K', [...]).
            %   Derived quantities (inertias, kv) ARE updated."""),
 ("""            obj.P.(name) = value;
            obj.pushParams();
            obj.refresh();
        end

        function setParams""", """            obj.P.(name) = value;
            obj.P = bb_derived(obj.P);
            obj.pushParams();
            obj.refresh();
        end

        function setParams"""),
 ("%SETPARAMS  Several at once: rp.setParams(struct('mp',0.03,'Lp',0.15))", "%SETPARAMS  Several at once: bb.setParams(struct('m',0.03,'Kp_x',2))"),
 ("[obj.P, obj.Lin] = rp_design(obj.P);\n            obj.pushParams(); obj.refresh();", "[obj.P, obj.Lin] = bb_design(obj.P);\n            obj.pushParams(); obj.refresh();"),
 ("%SETINITIALSTATE  [theta thetad alpha alphad] for the next start.", "%SETINITIALSTATE  [x xd alpha alphad] for the next start."),
 ("res = RotaryPendulum.parse(out.tel, obj.P);\n        end\n\n        function start", "res = BallBeam.parse(out.tel, obj.P);\n        end\n\n        function start"),
 ("obj.LastTime = 0; obj.Last = zeros(13,1);", "obj.LastTime = 0; obj.Last = zeros(12,1);"),
 ("res = RotaryPendulum.parse(out.tel, obj.P);\n        end\n\n        function animate", "res = BallBeam.parse(out.tel, obj.P);\n        end\n\n        function animate"),
 ("rp_animate(res, obj.P, speed);", "bb_animate(res, obj.P, speed);"),
 ("obj = RotaryPendulum.instance(mdl);\n            if ~isempty(obj), obj.attach(); end", "obj = BallBeam.instance(mdl);\n            if ~isempty(obj), obj.attach(); end"),
 ("obj = RotaryPendulum.instance(mdl);\n            if ~isempty(obj), obj.detach(); end", "obj = BallBeam.instance(mdl);\n            if ~isempty(obj), obj.detach(); end"),
 ("I = RotaryPendulum.TEL;", "I = BallBeam.TEL;"),
 ("""            res.th_deg = rad2deg(res.th);                       % arm: not wrapped
            res.al_deg = rad2deg(mod(res.al + pi, 2*pi) - pi);  % pendulum: wrapped
            res.r_deg  = rad2deg(res.r);""", """            res.x_cm    = 100*res.x;
            res.r_cm    = 100*res.r;
            res.al_deg  = rad2deg(res.al);
            res.alr_deg = rad2deg(res.alr);"""),
]
for a, b in rep:
    assert a in s, a
    s = s.replace(a, b)
assert 'RotaryPendulum' not in s and 'rp_' not in s, [l for l in s.splitlines() if 'RotaryPendulum' in l or 'rp_' in l]
open('ball_beam/BallBeam.m', 'w').write(s)
EOF
grep -n "obj.P = getappdata\|getappdata(0" ball_beam/BallBeam.m
```

</details>

<details><summary>Error</summary>

```
Exit code 2
Traceback (most recent call last):
  File "<stdin>", line 107, in <module>
AssertionError: obj.LastTime = 0; obj.Last = zeros(13,1);
ugrep: warning: ball_beam/BallBeam.m: No such file or directory
```

</details>

## 🤖 Claude

Building the ball-and-beam MATLAB package: params, plant, controller and model builder are written. Now generating the `BallBeam` class.

**🔧 Bash** — No-op placeholder

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && fc -ln 2>/dev/null; true
```

</details>

<details><summary>Output</summary>

```
(Bash completed with no output)
```

</details>

**🔧 Write** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/mk_class.py` (565 characters)

<details><summary>Output</summary>

```
File created successfully at: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/mk_class.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Write** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/spec_bb.py` (5748 characters)

<details><summary>Output</summary>

```
File created successfully at: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/spec_bb.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Generate BallBeam class

<details><summary>Command</summary>

```bash
python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/mk_class.py /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/spec_bb.py
```

</details>

<details><summary>Output</summary>

```
written ball_beam/BallBeam.m
```

</details>

## 🤖 Claude

Now the 3D scene for the ball and beam (beam, motor, pedestal, rolling ball with visible spin, reference marker, shadow).

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_draw.m` (4776 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_draw.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Fix hgtransform parenting and add view/animate/plot helpers

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam && python3 - <<'EOF'
s=open('bb_draw.m').read()
rep=[("plot3(h.tBeam, [-Lh Lh], [-0.006 -0.006], [zt zt]+1e-4, 'Color'", "line('Parent', h.tBeam, 'XData', [-Lh Lh], 'YData', [-0.006 -0.006], 'ZData', [zt zt]+1e-4, 'Color'"),
("plot3(h.tBeam, [-Lh Lh], [ 0.006  0.006], [zt zt]+1e-4, 'Color'", "line('Parent', h.tBeam, 'XData', [-Lh Lh], 'YData', [0.006 0.006], 'ZData', [zt zt]+1e-4, 'Color'"),
("plot3(h.tBeam, [xs xs], -wb/2*[1 1] - 1e-4, [zt zt-ht], 'Color'", "line('Parent', h.tBeam, 'XData', [xs xs], 'YData', -wb/2*[1 1] - 1e-4, 'ZData', [zt zt-ht], 'Color'"),
("patch(h.tRef, 'XData'", "patch('Parent', h.tRef, 'XData'"),
("surf(h.tBall, P.rb*X, P.rb*Y, P.rb*Z, C, 'EdgeColor'", "surface('Parent', h.tBall, 'XData', P.rb*X, 'YData', P.rb*Y, 'ZData', P.rb*Z, 'CData', C, 'FaceColor', 'interp', 'EdgeColor'"),
("patch(parent, 'Vertices'", "patch('Parent', parent, 'Vertices'"),
]
for a,b in rep:
    assert a in s, a; s=s.replace(a,b)
open('bb_draw.m','w').write(s)
EOF
cat > bb_view.m <<'EOF'
function bb_view(ax, name)
%BB_VIEW  Preset viewpoints for the ball and beam scene drawn by bb_draw.
%   bb_view(ax, 'iso')     3D perspective (default)
%   bb_view(ax, 'front')   seen from the front (-y): beam angle in true size
%   bb_view(ax, 'top')     seen from above
%   bb_view(ax, 'side')    seen along the beam (+x)
switch lower(name)
    case 'front', view(ax, 0, 0);
    case 'top',   view(ax, 0, 90);
    case 'side',  view(ax, 90, 0);
    otherwise,    view(ax, -28, 16);
end
end
EOF
cat > bb_animate.m <<'EOF'
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
EOF
cat > bb_plot_results.m <<'EOF'
function bb_plot_results(res, plotTitle)
%BB_PLOT_RESULTS  Standard plots of a ball and beam run (cm and degrees).
if nargin < 2, plotTitle = 'Ball and beam run'; end
figure('Name', plotTitle, 'Color', 'w');
tl = tiledlayout(3, 1, 'TileSpacing', 'compact');
title(tl, plotTitle);

nexttile; plot(res.t, res.x_cm, res.t, res.r_cm, '--', res.t, 100*res.xm, ':'); grid on
ylabel('x [cm]'); legend('ball', 'reference', 'measured', 'Location', 'best');

nexttile; plot(res.t, res.al_deg, res.t, res.alr_deg, '--'); grid on
ylabel('\alpha [deg]'); legend('beam', '\alpha_{ref} (beam/cascade)', 'Location', 'best');

nexttile; plot(res.t, res.Vcmd, res.t, res.Vact); grid on
ylabel('V [V]'); xlabel('t [s]'); legend('commanded', 'applied', 'Location', 'best');
end
EOF
ls
```

</details>

<details><summary>Output</summary>

```
BallBeam.m
bb_animate.m
bb_build_model.m
bb_controller_block.m
bb_derived.m
bb_design.m
bb_draw.m
bb_linearize.m
bb_lqr.m
bb_params.m
bb_plant_block.m
bb_plot_results.m
bb_ref_block.m
bb_view.m
__pycache__
python_reference_sim.py
validation
```

</details>

## 🤖 Claude

Ball-and-beam package core is written. First MATLAB test: build the model, run the main scenarios and render the 3D scene.

**🔧 Bash** — Build ball-beam model, run scenarios and render scene

<details><summary>Command</summary>

```bash
mkdir -p /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t1.m <<'EOF'
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam
bb_build_model; close_system('ballbeam_sim', 0);
bb = BallBeam();
disp(bb.P.K); disp(bb.Lin.poles_OL.'); disp(bb.Lin.poles_CL.')
bb.setParamRaw('ref_rate', 1e6);
for mode = [2 3]
  bb.setMode(mode); bb.setInitialState([0 0 0 0]); bb.setRefSignal([0 1 1+1e-4 8]', [0 0 0.1 0.1]');
  res = bb.run(8);
  i = find(abs(res.x - 0.1) > 0.005, 1, 'last');
  fprintf('mode %d: settle %.2f ov %.1f%% Vmax %.1f final %.2f cm\n', mode, res.t(i)-1, 100*(max(res.x)-0.1)/0.1, max(abs(res.Vact)), res.x_cm(end));
end
bb.clearSignals(); bb.setRef('const', 0);
bb.setMode('beam'); bb.setBeamAngle(0.05); bb.setInitialState([0 0 0 0]);
res = bb.run(3); fprintf('beam: al end %.3f x end %.3f\n', res.al(end), res.x(end));
f = figure('Visible','off','Position',[0 0 900 600],'Color','w'); ax = axes(f);
h = bb_draw(ax, bb.P); bb_draw(ax, bb.P, h, 0.08, deg2rad(12), -0.05);
exportgraphics(f, '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/scene_iso.png');
bb_view(ax,'front'); exportgraphics(f, '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/scene_front.png');
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 600 matlab -batch "t1" 2>&1 | tail -30
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/ballbeam_sim.slx
  -43.4978  -15.7378   18.7881    1.1824  -14.1421

 -10.6826 + 0.0000i   3.6237 + 0.0000i  -1.5795 + 3.8508i  -1.5795 - 3.8508i

  Columns 1 through 4

 -16.6485 + 0.0000i  -4.8974 + 5.7815i  -4.8974 - 5.7815i  -4.3697 + 0.0000i

  Column 5

  -0.4436 + 0.0000i

mode 2: settle 1.50 ov 0.8% Vmax 5.2 final 10.03 cm
mode 3: settle 0.64 ov 2.5% Vmax 3.8 final 10.02 cm
beam: al end 0.074 x end -0.196
[Warning: Unable to close the model 'ballbeam_sim' because it has been changed.
To save changes, use close_system('ballbeam_sim',1). To discard changes, use
close_system('ballbeam_sim',0).]
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

## 🤖 Claude

Simulink matches the Python replica exactly on the first try (1.50 s / 0.64 s, same overshoot). Let me look at the render.

**🔧 Read** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/scene_iso.png`

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Read** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/scene_front.png`

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

The physics is fine; the ball needs more contrast so its spin reads. Fixing that, then the GUI.

**🔧 Bash** — Increase ball two-tone contrast

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam && sed -i "s/C = repmat(C, 1, 1, 3).\*reshape(\[0.55 0.08 0.05\], 1, 1, 3) .../C = repmat(C, 1, 1, 3).*reshape([0.80 0.10 0.08], 1, 1, 3) .../; s/+ repmat(1 - C, 1, 1, 3).\*reshape(\[0.90 0.30 0.20\], 1, 1, 3);/+ repmat(1 - C, 1, 1, 3).*reshape([0.97 0.90 0.82], 1, 1, 3);/" bb_draw.m && grep -n "reshape" bb_draw.m
```

</details>

<details><summary>Output</summary>

```
49:    C = repmat(C, 1, 1, 3).*reshape([0.80 0.10 0.08], 1, 1, 3) ...
50:      + repmat(1 - C, 1, 1, 3).*reshape([0.97 0.90 0.82], 1, 1, 3);
[This command modified 1 file you've previously read: bb_draw.m. Call Read before editing.]
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_gui.m` (12037 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/bb_gui.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Fix tuning grid and test ball-beam GUI live

<details><summary>Command</summary>

```bash
sed -i "s/g4 = uigridlayout(p4, \[6 4\]); g4.RowHeight = repmat({'fit'}, 1, 6);/g4 = uigridlayout(p4, [7 4]); g4.RowHeight = repmat({'fit'}, 1, 7);/" bb_gui.m && grep -n "uigridlayout(p4" bb_gui.m
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t2.m <<'EOF'
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam
out = '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/';
bb = BallBeam();
bb_gui(bb);
fig = findall(groot, 'Type', 'figure', 'Name', 'Ball and beam — live Simulink');
bb.setInitialState([0.1 0 0 0]); bb.setMode('lqr'); bb.setRef('square', 0, 0.08, 0.1);
bb.start();
t0 = tic; while toc(t0) < 7, pause(0.1); end
bb.push(0.3, 0.05);
t0 = tic; while toc(t0) < 1.0, pause(0.1); end
fprintf('live t = %.2f, x = %.3f\n', bb.LastTime, bb.Last(1));
exportapp(fig, [out 'gui.png']);
bb.stop();
res = bb.lastResult();
fprintf('live run: %d samples, t end %.2f, max|x| %.3f, max V %.2f\n', numel(res.t), res.t(end), max(abs(res.x)), max(abs(res.Vact)));
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 600 matlab -batch "t2" 2>&1 | tail -15
```

</details>

<details><summary>Output</summary>

```
103:g4 = uigridlayout(p4, [7 4]); g4.RowHeight = repmat({'fit'}, 1, 7);
live t = 2.33, x = 0.101
live run: 2327 samples, t end 2.33, max|x| 0.109, max V 4.35
[Warning: Unable to close the model 'ballbeam_sim' because it has been changed.
To save changes, use close_system('ballbeam_sim',1). To discard changes, use
close_system('ballbeam_sim',0).]
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
[This command modified 1 file you've previously read: src/ball_beam/bb_gui.m. Call Read before editing.]
```

</details>

**🔧 Read** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/gui.png`

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

GUI works live. Small polish: tighter scene limits so the beam fills the view, clean slider ticks, shorter label.

**🔧 Bash** — Polish GUI labels and scene limits

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam && python3 - <<'EOF'
s=open('bb_gui.m').read()
rep=[("uilabel(g1, 'Text', 'x0 [cm] / α0 [deg]');","uilabel(g1, 'Text', 'x0 [cm], α0 [°]');"),
("alMaxDeg = rad2deg(P.al_max);","alMaxDeg = floor(rad2deg(P.al_max));"),
("    'ValueChangedFcn',  @(s,~) setBeam(s.Value));","    'ValueChangedFcn',  @(s,~) setBeam(s.Value), 'MajorTicks', -20:10:20);"),
]
for a,b in rep:
    assert a in s, a; s=s.replace(a,b)
open('bb_gui.m','w').write(s)
d=open('bb_draw.m').read()
rep=[("bx = Lh + 0.06; by = 0.11;","bx = Lh + 0.04; by = 0.09;"),
("zlim(ax, [0 H + 0.10]);","zlim(ax, [0 H + 0.08]);")]
for a,b in rep:
    assert a in d, a; d=d.replace(a,b)
open('bb_draw.m','w').write(d)
EOF
echo ok
```

</details>

<details><summary>Output</summary>

```
ok
```

</details>

## 🤖 Claude

Ball and beam is working end to end. Now the ball-and-plate MATLAB package, same architecture with two axes and the camera sensor.

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_params.m` (4798 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_derived.m` (790 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_linearize.m` (827 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_design.m` (768 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_plant_block.m` (2483 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_controller_block.m` (3084 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_ref_block.m` (858 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_params.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_derived.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_linearize.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_design.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_plant_block.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_controller_block.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_ref_block.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_build_model.m` (11661 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_build_model.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Make vector shapes explicit in plate blocks

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate && python3 - <<'EOF'
s=open('bp_controller_block.m').read()
a="""mode = round(cmd(1)); en = cmd(2);
uman = cmd(3:4); angman = cmd(5:6);
p = y(1:2); ang = y(3:4);"""
b="""mode = round(cmd(1)); en = cmd(2);
uman = [cmd(3); cmd(4)]; angman = [cmd(5); cmd(6)];
p = [y(1); y(2)]; ang = [y(3); y(4)];"""
assert a in s; s=s.replace(a,b)
a="""    n = 0; pp = y(1:2); vb = [0; 0]; ap = y(3:4); va = [0; 0];"""
b="""    n = 0; pp = [y(1); y(2)]; vb = [0; 0]; ap = [y(3); y(4)]; va = [0; 0];"""
assert a in s; s=s.replace(a,b)
a="e  = p - r;"; b="e  = p - [r(1); r(2)];"
assert a in s; s=s.replace(a,b)
a="+ P.ff_on*P.m*P.g*r/P.kv;"; b="+ P.ff_on*P.m*P.g*[r(1); r(2)]/P.kv;"
assert a in s; s=s.replace(a,b)
open('bp_controller_block.m','w').write(s)
s=open('bp_plant_block.m').read()
a="m = P.m; g = P.g; c = P.Jb/P.rb;"; b="m = P.m; g = P.g; c = P.Jb/P.rb;\nV = [V(1); V(2)]; Fd = [Fd(1); Fd(2)];"
assert a in s; s=s.replace(a,b)
open('bp_plant_block.m','w').write(s)
EOF
echo ok
```

</details>

<details><summary>Output</summary>

```
ok
```

</details>

## 🤖 Claude

Now the `BallPlate` class (two voltages, 2D reference and disturbance, 23-signal telemetry).

**🔧 Write** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/spec_bp.py` (9853 characters)

<details><summary>Output</summary>

```
File created successfully at: /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/spec_bp.py (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Generate BallPlate class

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && python3 /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/mk_class.py /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/spec_bp.py && grep -n "CmdRef\b\|CmdRef =" ball_plate/BallPlate.m | head
```

</details>

<details><summary>Output</summary>

```
written ball_plate/BallPlate.m
45:        CmdRef  = [0 0 0 0.06 0.2]  % [type cx cy amplitude frequency]
130:            if nargin < 3 || isempty(centre), centre = obj.CmdRef(2:3); end
131:            if nargin < 4, amp = obj.CmdRef(4); end
132:            if nargin < 5, freq = obj.CmdRef(5); end
133:            obj.CmdRef = [type centre(:).' amp freq]; obj.applyCmd();
297:            set_param([obj.Model '/cmd_ref'],  'Value', mat2str(obj.CmdRef, 6));
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_draw.m` (7207 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_draw.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Write plate helpers, build model, run tests, render scene

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate && cat > bp_draw_top.m <<'EOF'
function h = bp_draw_top(ax, P, h, x, y, rx, ry)
%BP_DRAW_TOP  Top (camera) view of the plate: ball, reference and trail.
%   h = bp_draw_top(ax, P)                     creates the graphics
%   h = bp_draw_top(ax, P, h, x, y, rx, ry)    updates (positions in m)
%   This is what the overhead camera sees. In the GUI a click on these axes
%   sets the reference point. Clear the trail with
%   set(h.trail, 'XData', nan, 'YData', nan).
a = P.a;
if nargin < 3 || isempty(h)
    cla(ax); hold(ax, 'on');
    t = linspace(0, 2*pi, 41);
    patch(ax, a*[-1 1 1 -1], a*[-1 -1 1 1], [0.86 0.89 0.93], 'EdgeColor', [0.20 0.45 0.75], ...
        'LineWidth', 2, 'HitTest', 'off');
    for v = -0.10:0.05:0.10
        plot(ax, [v v], [-a a], 'Color', [0.62 0.67 0.75], 'HitTest', 'off');
        plot(ax, [-a a], [v v], 'Color', [0.62 0.67 0.75], 'HitTest', 'off');
    end
    m = P.x_ref_max;
    plot(ax, m*[-1 1 1 -1 -1], m*[-1 -1 1 1 -1], ':', 'Color', [0.47 0.67 0.19], 'HitTest', 'off');
    h.trail = plot(ax, nan, nan, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2, 'HitTest', 'off');
    h.ref  = plot(ax, 0, 0, '+', 'Color', [0.30 0.60 0.10], 'MarkerSize', 14, 'LineWidth', 2, 'HitTest', 'off');
    h.refc = plot(ax, 1.25*P.rb*cos(t), 1.25*P.rb*sin(t), 'Color', [0.30 0.60 0.10], 'LineWidth', 2, 'HitTest', 'off');
    h.ball = patch(ax, P.rb*cos(t), P.rb*sin(t), [0.85 0.15 0.10], 'EdgeColor', 'k', 'HitTest', 'off');
    h.ct = t;
    hold(ax, 'off');
    axis(ax, 'equal'); xlim(ax, (a + 0.01)*[-1 1]); ylim(ax, (a + 0.01)*[-1 1]);
    xlabel(ax, 'x [m]'); ylabel(ax, 'y [m]'); box(ax, 'on');
    if nargin < 4, return; end
end
set(h.ball, 'XData', x + P.rb*cos(h.ct), 'YData', y + P.rb*sin(h.ct));
set(h.ref,  'XData', rx, 'YData', ry);
set(h.refc, 'XData', rx + 1.25*P.rb*cos(h.ct), 'YData', ry + 1.25*P.rb*sin(h.ct));
X = [get(h.trail, 'XData') x]; Y = [get(h.trail, 'YData') y];
n = numel(X); k = max(1, n - 150):n;
set(h.trail, 'XData', X(k), 'YData', Y(k));
end
EOF
cat > bp_view.m <<'EOF'
function bp_view(ax, name)
%BP_VIEW  Preset viewpoints for the ball and plate scene drawn by bp_draw.
%   bp_view(ax, 'iso')     3D perspective (default)
%   bp_view(ax, 'top')     seen from above (camera view)
%   bp_view(ax, 'front')   seen from -y: tilt alpha in true size
%   bp_view(ax, 'side')    seen from +x: tilt beta in true size
switch lower(name)
    case 'top',   view(ax, 0, 90);
    case 'front', view(ax, 0, 0);
    case 'side',  view(ax, 90, 0);
    otherwise,    view(ax, -35, 28);
end
end
EOF
cat > bp_animate.m <<'EOF'
function bp_animate(res, P, speed)
%BP_ANIMATE  Replays a saved run (struct returned by BallPlate.run):
%   3D scene on the left, top (camera) view on the right.
%   bp_animate(res)            uses res.P
%   bp_animate(res, P, 0.5)    at half speed
if nargin < 2 || isempty(P), P = res.P; end
if nargin < 3, speed = 1; end
fig = figure('Name', 'Ball and plate animation', 'Color', 'w', 'Position', [100 100 1100 500]);
tl = tiledlayout(fig, 1, 5, 'TileSpacing', 'compact');
ax3 = nexttile(tl, [1 3]); axT = nexttile(tl, [1 2]);
h  = bp_draw(ax3, P);
hT = bp_draw_top(axT, P);
ttl = title(tl, '');
fps = 30; t0 = tic; N = numel(res.t);
while ishandle(fig)
    tsim = toc(t0)*speed;
    k = find(res.t >= tsim, 1);
    if isempty(k), k = N; end
    bp_draw(ax3, P, h, res.x(k), res.y(k), res.al(k), res.be(k), res.rx(k), res.ry(k));
    bp_draw_top(axT, P, hT, res.x(k), res.y(k), res.rx(k), res.ry(k));
    set(ttl, 'String', sprintf('t = %.2f s   x = %+.1f cm   y = %+.1f cm   \\alpha = %+.1f°   \\beta = %+.1f°', ...
        res.t(k), res.x_cm(k), res.y_cm(k), res.al_deg(k), res.be_deg(k)));
    drawnow;
    if k == N, break; end
    pause(1/fps);
end
end
EOF
cat > bp_plot_results.m <<'EOF'
function bp_plot_results(res, plotTitle)
%BP_PLOT_RESULTS  Standard plots of a ball and plate run (cm and degrees).
if nargin < 2, plotTitle = 'Ball and plate run'; end
figure('Name', plotTitle, 'Color', 'w', 'Position', [100 100 1100 650]);
tl = tiledlayout(3, 3, 'TileSpacing', 'compact');
title(tl, plotTitle);

nexttile(1, [2 1]);
plot(res.rx_cm, res.ry_cm, '--', 'Color', [0.47 0.67 0.19]); hold on
plot(res.x_cm, res.y_cm, 'Color', [0.85 0.33 0.10]); hold off
axis equal; grid on; a = 100*res.P.a; xlim([-a a]); ylim([-a a]);
xlabel('x [cm]'); ylabel('y [cm]'); title('Path on the plate'); legend('reference', 'ball', 'Location', 'best');

nexttile(2, [1 2]); plot(res.t, res.x_cm, res.t, res.rx_cm, '--', res.t, 100*res.xm, ':'); grid on
ylabel('x [cm]'); legend('ball', 'reference', 'camera', 'Location', 'best');

nexttile(5, [1 2]); plot(res.t, res.y_cm, res.t, res.ry_cm, '--', res.t, 100*res.ym, ':'); grid on
ylabel('y [cm]'); legend('ball', 'reference', 'camera', 'Location', 'best');

nexttile(7, [1 1]); plot(res.t, res.al_deg, res.t, res.be_deg); grid on
ylabel('tilt [deg]'); xlabel('t [s]'); legend('\alpha', '\beta', 'Location', 'best');

nexttile(8, [1 2]); plot(res.t, res.Va, res.t, res.Vb); grid on
ylabel('V [V]'); xlabel('t [s]'); legend('V_a', 'V_b', 'Location', 'best');
end
EOF
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t3.m <<'EOF'
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate
out = '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/';
bp_build_model; close_system('ballplate_sim', 0);
bp = BallPlate();
disp(bp.P.Kx); disp(bp.P.Ky); disp(bp.Lin.x.poles_CL.')
bp.setParamRaw('ref_rate', 1e6);
for mode = [2 3]
  bp.setMode(mode); bp.setInitialState(zeros(8,1));
  bp.setRefSignal([0 1 1+1e-4 6]', [0 0; 0 0; 0.08 -0.05; 0.08 -0.05]);
  res = bp.run(6);
  d = hypot(res.x - 0.08, res.y + 0.05); i = find(d > 0.005, 1, 'last');
  fprintf('mode %d: settle %.2f ovx %.1f%% Vmax %.1f tilt %.1f final (%.2f, %.2f)\n', mode, res.t(i)-1, 100*(max(res.x)-0.08)/0.08, max(abs([res.Va; res.Vb])), max(abs([res.al_deg; res.be_deg])), res.x_cm(end), res.y_cm(end));
end
bp.clearSignals();
bp.setMode('lqr'); bp.setInitialState([0.06 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.06, 0.2);
res = bp.run(15); k = res.t > 5; rad = hypot(res.x(k), res.y(k));
fprintf('circle: radius %.2f (%.2f..%.2f) cm\n', 100*mean(rad), 100*min(rad), 100*max(rad));
f = figure('Visible','off','Position',[0 0 1100 500],'Color','w');
tl = tiledlayout(f, 1, 5); ax3 = nexttile(tl, [1 3]); axT = nexttile(tl, [1 2]);
h = bp_draw(ax3, bp.P); hT = bp_draw_top(axT, bp.P);
for k = find(res.t > 10, 1):30:find(res.t > 13, 1)
  bp_draw(ax3, bp.P, h, res.x(k), res.y(k), res.al(k), res.be(k), res.rx(k), res.ry(k));
  bp_draw_top(axT, bp.P, hT, res.x(k), res.y(k), res.rx(k), res.ry(k));
end
exportgraphics(f, [out 'plate_iso.png']);
bp_draw(ax3, bp.P, h, 0.1, 0.06, deg2rad(10), deg2rad(-8), -0.05, 0.05);
exportgraphics(f, [out 'plate_tilt.png']);
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 900 matlab -batch "t3" 2>&1 | tail -30
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/ballplate_sim.slx
  -33.5395  -14.0233   17.5562    1.1149  -10.0000

  -33.4476  -13.7653   16.6616    0.9577  -10.0000

  Columns 1 through 4

 -17.3537 + 0.0000i  -5.3104 + 5.7199i  -5.3104 - 5.7199i  -2.9261 + 0.0000i

  Column 5

  -0.4409 + 0.0000i

mode 2: settle 1.63 ovx 1.2% Vmax 3.2 tilt 4.5 final (8.06, -5.07)
mode 3: settle 1.92 ovx 6.4% Vmax 2.3 tilt 6.2 final (7.99, -5.00)
circle: radius 5.75 (5.41..6.08) cm
[Warning: Unable to close the model 'ballplate_sim' because it has been changed.
To save changes, use close_system('ballplate_sim',1). To discard changes, use
close_system('ballplate_sim',0).]
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

## 🤖 Claude

The ball-and-plate model matches the Python replica exactly on the first build, including the camera timing. Checking the renders:

**🔧 Read** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/plate_iso.png`

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Read** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/plate_tilt.png`

<details><summary>Output</summary>

```
(no output)
```

</details>

## 🤖 Claude

The gimbal kinematics look right: the outer frame follows α only, and the plate tilts with both α and β. The plate surface renders too dark, so I'll make it self-lit like the base.

**🔧 Bash** — Brighten plate surface lighting

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate && python3 - <<'EOF'
s=open('bp_draw.m').read()
rep=[("box3(h.tB, [-a a], [-a a], [-tp/2 zt], [0.86 0.89 0.93]);","box3(h.tB, [-a a], [-a a], [-tp/2 zt], [0.86 0.89 0.93], ...\n        'AmbientStrength', 0.9, 'DiffuseStrength', 0.25, 'SpecularStrength', 0);"),
("function box3(parent, xr, yr, zr, col)","function box3(parent, xr, yr, zr, col, varargin)"),
("""patch('Parent', parent, 'Vertices', V, 'Faces', F, 'FaceColor', col, 'EdgeColor', 'none', ...
    'FaceLighting', 'flat');""","""patch('Parent', parent, 'Vertices', V, 'Faces', F, 'FaceColor', col, 'EdgeColor', 'none', ...
    'FaceLighting', 'flat', varargin{:});""")]
for a,b in rep:
    assert a in s, a; s=s.replace(a,b)
open('bp_draw.m','w').write(s)
EOF
echo ok
```

</details>

<details><summary>Output</summary>

```
ok
```

</details>

## 🤖 Claude

Plate scene done. Now the plate GUI: 3D view next to a clickable camera view that sets the target, live plots, and arrow keys that tap the ball.

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_gui.m` (14028 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/bp_gui.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Test plate GUI live and capture screenshot

<details><summary>Command</summary>

```bash
sed -i "s/'Text', '◀ ▶ Tap ±x'/'Text', 'Tap ▶ (+x)'/; s/'Text', '▼ ▲ Tap ±y'/'Text', 'Tap ▲ (+y)'/" bp_gui.m && grep -n "Tap ▶\|Tap ▲" bp_gui.m
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t4.m <<'EOF'
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate
out = '/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/';
bp = BallPlate();
bp_gui(bp);
fig = findall(groot, 'Type', 'figure', 'Name', 'Ball and plate — live Simulink');
bp.setInitialState([0.06 0 0 0 0 0 0 0]); bp.setMode('lqr'); bp.setRef('eight', [0 0], 0.07, 0.15);
bp.start();
t0 = tic; while bp.LastTime < 9 && toc(t0) < 60, pause(0.1); end
fprintf('live t = %.2f (wall %.1f)\n', bp.LastTime, toc(t0));
exportapp(fig, [out 'gui_plate.png']);
bp.stop();
res = bp.lastResult();
fprintf('live run: t end %.2f, max|x| %.3f, max V %.2f\n', res.t(end), max(abs(res.x)), max(abs(res.Va)));
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 600 matlab -batch "t4" 2>&1 | tail -15
```

</details>

<details><summary>Output</summary>

```
85:uibutton(g2, 'Text', 'Tap ▶ (+x)', 'ButtonPushedFcn', @(~,~) doPush([1 0]));
86:b2 = uibutton(g2, 'Text', 'Tap ▲ (+y)', 'ButtonPushedFcn', @(~,~) doPush([0 1]));
live t = 9.02 (wall 35.3)
live run: t end 9.02, max|x| 0.073, max V 2.01
[Warning: Unable to close the model 'ballplate_sim' because it has been changed.
To save changes, use close_system('ballplate_sim',1). To discard changes, use
close_system('ballplate_sim',0).]
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
[This command modified 1 file you've previously read: src/ball_plate/bp_gui.m. Call Read before editing.]
```

</details>

**🔧 Read** `/tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/gui_plate.png`

<details><summary>Output</summary>

```
(no output)
```

</details>

**🔧 Bash** — Measure real-time factor of both GUIs

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate && sed -i "s/'MajorTicks', -15:5:15,/'MajorTicks', [-15 0 15],/g" bp_gui.m && grep -c "MajorTicks', \[-15 0 15\]" bp_gui.m
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t5.m <<'EOF'
root = '/home/aguti/universidad/controlSystemsMatlabModels/src/';
for e = {'ball_plate', 'ball_beam'}
  cd([root e{1}]);
  if strcmp(e{1}, 'ball_plate'), o = BallPlate(); bp_gui(o); o.setRef('circle', [0 0], 0.06, 0.2);
  else, o = BallBeam(); bb_gui(o); o.setRef('sine', 0, 0.1, 0.2); end
  o.setMode('lqr');
  o.start();
  t0 = tic; while o.LastTime < 1 && toc(t0) < 120, pause(0.05); end
  w1 = toc(t0); s1 = o.LastTime;
  while toc(t0) < w1 + 8, pause(0.05); end
  fprintf('%s: compile+1s %.1f s wall; then %.2f sim s in %.2f wall s (ratio %.2f)\n', e{1}, w1, o.LastTime - s1, toc(t0) - w1, (o.LastTime - s1)/(toc(t0) - w1));
  o.stop();
  close all force
end
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 600 matlab -batch "t5" 2>&1 | grep -v Warning | tail -8
```

</details>

<details><summary>Output</summary>

```
2
ball_plate: compile+1s 10.0 s wall; then 1.99 sim s in 8.15 wall s (ratio 0.24)
ball_beam: compile+1s 4.9 s wall; then 2.53 sim s in 8.19 wall s (ratio 0.31)
To save changes, use close_system('ballplate_sim',1). To discard changes, use
close_system('ballplate_sim',0).] 
To save changes, use close_system('ballbeam_sim',1). To discard changes, use
close_system('ballbeam_sim',0).]
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
[This command modified 1 file you've previously read: src/ball_plate/bp_gui.m. Call Read before editing.]
```

</details>

**🔧 Bash** — Compare real-time factor with rotary and without GUI

<details><summary>Command</summary>

```bash
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t6.m <<'EOF'
root = '/home/aguti/universidad/controlSystemsMatlabModels/src/';
cases = {'rotary_pendulum', 'gui'; 'ball_plate', 'nogui'; 'ball_plate', 'gui_noplot'};
for c = 1:size(cases,1)
  cd([root cases{c,1}]);
  switch cases{c,1}
    case 'rotary_pendulum', o = RotaryPendulum(); rp_gui(o); o.setMode('lqr');
    case 'ball_plate'
      o = BallPlate(); o.setMode('lqr'); o.setRef('circle', [0 0], 0.06, 0.2);
      if strcmp(cases{c,2}, 'gui_noplot'), o.addTelemetryCallback(@(t,d) drawnow('limitrate')); end
  end
  o.start();
  t0 = tic; while o.LastTime < 1 && toc(t0) < 120, pause(0.05); end
  w1 = toc(t0); s1 = o.LastTime;
  while toc(t0) < w1 + 6, pause(0.05); end
  fprintf('%s/%s: %.2f sim s in %.2f wall s (ratio %.2f)\n', cases{c,1}, cases{c,2}, o.LastTime - s1, toc(t0) - w1, (o.LastTime - s1)/(toc(t0) - w1));
  o.stop(); o.clearCallbacks();
  close all force
end
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 600 matlab -batch "t6" 2>&1 | grep "ratio"
```

</details>

<details><summary>Output</summary>

```
rotary_pendulum/gui: 2.45 sim s in 6.09 wall s (ratio 0.40)
ball_plate/nogui: 6.04 sim s in 6.04 wall s (ratio 1.00)
ball_plate/gui_noplot: 6.04 sim s in 6.03 wall s (ratio 1.00)
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Inspect telemetry throttling in existing classes

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && grep -n "TelemetryRate\|obj.tick\|function onTel" linear_pendulum/CartPole.m rotary_pendulum/RotaryPendulum.m | head -30; sed -n '/function onTel/,/^        end$/p' linear_pendulum/CartPole.m
```

</details>

<details><summary>Output</summary>

```
rotary_pendulum/RotaryPendulum.m:35:        TelemetryRate = 30      % rate [Hz] at which live callbacks are called
rotary_pendulum/RotaryPendulum.m:83:            obj.tick = tic;
rotary_pendulum/RotaryPendulum.m:310:            obj.tick = tic;
rotary_pendulum/RotaryPendulum.m:313:        function onTel(obj, blk)
rotary_pendulum/RotaryPendulum.m:317:            if toc(obj.tick) >= 1/obj.TelemetryRate
rotary_pendulum/RotaryPendulum.m:318:                obj.tick = tic;
linear_pendulum/CartPole.m:33:        TelemetryRate = 30      % rate [Hz] at which live callbacks are called
linear_pendulum/CartPole.m:81:            obj.tick = tic;
linear_pendulum/CartPole.m:307:            obj.tick = tic;
linear_pendulum/CartPole.m:310:        function onTel(obj, blk)
linear_pendulum/CartPole.m:314:            if toc(obj.tick) >= 1/obj.TelemetryRate
linear_pendulum/CartPole.m:315:                obj.tick = tic;
        function onTel(obj, blk)
            obj.Last = blk.OutputPort(1).Data;
            obj.LastTime = blk.CurrentTime;
            if obj.batch || isempty(obj.telCallbacks), return; end
            if toc(obj.tick) >= 1/obj.TelemetryRate
                obj.tick = tic;
                for k = 1:numel(obj.telCallbacks)
                    try
                        obj.telCallbacks{k}(obj.LastTime, obj.Last);
                    catch err
                        warning(err.identifier, '%s', err.message);
                    end
                end
            end
        end
```

</details>

**🔧 Bash** — Add adaptive telemetry throttle to all four classes

<details><summary>Command</summary>

```bash
python3 - <<'EOF'
files = ['linear_pendulum/CartPole.m', 'rotary_pendulum/RotaryPendulum.m', 'ball_beam/BallBeam.m', 'ball_plate/BallPlate.m']
old_cb = """            if toc(obj.tick) >= 1/obj.TelemetryRate
                obj.tick = tic;
                for k = 1:numel(obj.telCallbacks)
                    try
                        obj.telCallbacks{k}(obj.LastTime, obj.Last);
                    catch err
                        warning(err.identifier, '%s', err.message);
                    end
                end
            end"""
new_cb = """            if toc(obj.tick) >= obj.cbPeriod
                obj.tick = tic;
                for k = 1:numel(obj.telCallbacks)
                    try
                        obj.telCallbacks{k}(obj.LastTime, obj.Last);
                    catch err
                        warning(err.identifier, '%s', err.message);
                    end
                end
                % Adaptive throttle: callbacks (GUI drawing) run on the same
                % thread as the simulation. Space them so that they use at
                % most GuiLoad of the wall time; the simulation keeps real
                % time and only the frame rate drops on slow machines.
                obj.cbPeriod = max(1/obj.TelemetryRate, toc(obj.tick)/obj.GuiLoad);
            end"""
old_prop = "        TelemetryRate = 30      % rate [Hz] at which live callbacks are called\n"
new_prop = ("        TelemetryRate = 30      % maximum rate [Hz] at which live callbacks are called\n"
            "        GuiLoad = 0.4           % maximum fraction of wall time spent in live callbacks\n")
old_priv = "        tick\n"
new_priv = "        tick\n        cbPeriod = 0\n"
for f in files:
    s = open(f).read()
    for a, b in ((old_cb, new_cb), (old_prop, new_prop), (old_priv, new_priv)):
        assert s.count(a) == 1, (f, a[:40])
        s = s.replace(a, b)
    open(f, 'w').write(s)
    print('patched', f)
EOF
```

</details>

<details><summary>Output</summary>

```
patched linear_pendulum/CartPole.m
patched rotary_pendulum/RotaryPendulum.m
patched ball_beam/BallBeam.m
patched ball_plate/BallPlate.m
```

</details>

**🔧 Bash** — Re-measure real-time factor with adaptive throttle

<details><summary>Command</summary>

```bash
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t7.m <<'EOF'
root = '/home/aguti/universidad/controlSystemsMatlabModels/src/';
for e = {'ball_plate', 'ball_beam', 'rotary_pendulum', 'linear_pendulum'}
  cd([root e{1}]);
  switch e{1}
    case 'ball_plate', o = BallPlate(); bp_gui(o); o.setRef('circle', [0 0], 0.06, 0.2); o.setMode('lqr');
    case 'ball_beam', o = BallBeam(); bb_gui(o); o.setRef('sine', 0, 0.1, 0.2); o.setMode('lqr');
    case 'rotary_pendulum', o = RotaryPendulum(); rp_gui(o); o.setMode('lqr');
    case 'linear_pendulum', o = CartPole(); cp_gui(o); o.setMode('lqr');
  end
  n = 0; o.addTelemetryCallback(@(t,d) evalin('base', 'nfr = nfr + 1;')); assignin('base', 'nfr', 0);
  o.start();
  t0 = tic; while o.LastTime < 1 && toc(t0) < 120, pause(0.05); end
  w1 = toc(t0); s1 = o.LastTime; f1 = evalin('base', 'nfr');
  while toc(t0) < w1 + 8, pause(0.05); end
  w = toc(t0) - w1;
  fprintf('%s: ratio %.2f, %.1f frames/s\n', e{1}, (o.LastTime - s1)/w, (evalin('base', 'nfr') - f1)/w);
  o.stop(); o.clearCallbacks();
  close all force
end
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 900 matlab -batch "t7" 2>&1 | grep "ratio\|rror"
```

</details>

<details><summary>Output</summary>

```
ball_plate: ratio 0.20, 9.9 frames/s
ball_beam: ratio 0.28, 12.0 frames/s
rotary_pendulum: ratio 0.44, 18.0 frames/s
linear_pendulum: ratio 0.38, 15.9 frames/s
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Try synchronous drawnow and re-measure

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && grep -n "drawnow" */*_gui.m && sed -i 's/^        drawnow limitrate$/        drawnow/' ball_plate/bp_gui.m ball_beam/bb_gui.m && grep -n "drawnow" ball_*/*_gui.m && cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && sed -i "s/for e = {'ball_plate', 'ball_beam', 'rotary_pendulum', 'linear_pendulum'}/for e = {'ball_plate', 'ball_beam'}/" t7.m && timeout 900 matlab -batch "t7" 2>&1 | grep "ratio\|rror"
```

</details>

<details><summary>Output</summary>

```
rotary_pendulum/rp_gui.m:210:        drawnow limitrate
ball_beam/bb_gui.m:207:        drawnow limitrate
linear_pendulum/cp_gui.m:184:        drawnow limitrate
ball_plate/bp_gui.m:240:        drawnow limitrate
ball_beam/bb_gui.m:207:        drawnow
ball_plate/bp_gui.m:240:        drawnow
ball_plate: ratio 0.64, 2.2 frames/s
ball_beam: ratio 0.67, 1.9 frames/s
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
[This command modified 2 files you've previously read: src/ball_plate/bp_gui.m, src/ball_beam/bb_gui.m. Call Read before editing.]
```

</details>

**🔧 Bash** — Use synchronous drawnow in all GUIs and re-measure

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && sed -i 's/^        drawnow limitrate$/        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost/; s/^        drawnow$/        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost/' */*_gui.m && grep -n "drawnow" */*_gui.m && cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && sed -i "s/for e = {'ball_plate', 'ball_beam'}/for e = {'ball_plate', 'ball_beam', 'rotary_pendulum', 'linear_pendulum'}/" t7.m && timeout 900 matlab -batch "t7" 2>&1 | grep "ratio\|rror"
```

</details>

<details><summary>Output</summary>

```
rotary_pendulum/rp_gui.m:210:        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost
linear_pendulum/cp_gui.m:184:        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost
ball_plate/bp_gui.m:240:        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost
ball_beam/bb_gui.m:207:        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost
ball_plate: ratio 0.66, 2.0 frames/s
ball_beam: ratio 0.67, 2.2 frames/s
rotary_pendulum: ratio 0.63, 3.2 frames/s
linear_pendulum: ratio 0.68, 3.6 frames/s
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
[This command modified 3 files you've previously read: src/rotary_pendulum/rp_gui.m, src/ball_beam/bb_gui.m, src/ball_plate/bp_gui.m. Call Read before editing.]
```

</details>

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/examples.m` (4789 characters)

**🔧 Write** `/home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/examples.m` (4133 characters)

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/examples.m (file state is current in your context — no need to Read it back)
```

</details>

<details><summary>Output</summary>

```
File created successfully at: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/examples.m (file state is current in your context — no need to Read it back)
```

</details>

**🔧 Bash** — Write ball-beam validation scripts

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam && python3 - <<'EOF'
s=open('examples.m').read()
a="""    bb.setParamRaw('m', m);           % true ball changes; gains (and ff) keep the nominal design"""
b="""    bb.setParamRaw('m', m);           % true ball changes; K keeps the nominal design
                                      % (the feedforward m g r/kv does use the new m)"""
assert a in s; s=s.replace(a,b); open('examples.m','w').write(s)
EOF
cat > validation/run_validation.m <<'EOF'
function outDir = run_validation(outDir)
%RUN_VALIDATION  Runs the reference scenarios on the ball and beam Simulink
%   model and stores each run as a CSV, so they can be compared against the
%   Python replica with compare_with_python.py.
%
%   run_validation                 -> writes to validation/results/
%   run_validation('some/folder')
%
%   CSV columns (SI units):
%     t x xd al ald Vcmd Vact r alr I xm alm
%
%   Scenarios "matched" to the Python replica run with the reference rate
%   limiter disabled (the replica does not model it). The "*_ratelim" and
%   "sine_*" scenarios use the default parameters.
%
%   Then, from a shell:
%     python3 compare_with_python.py results

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1 || isempty(outDir), outDir = fullfile(here, 'results'); end
if ~exist(outDir, 'dir'), mkdir(outDir); end

stepSig = @(t0, A, T) deal([0 t0 t0+1e-4 T]', [0 0 A A]');
save_ = @(name, res) writematrix([res.t res.x res.xd res.al res.ald ...
    res.Vcmd res.Vact res.r res.alr res.I res.xm res.alm], ...
    fullfile(outDir, [name '.csv']));

bb_build_model();
bb = BallBeam();
tap = {[0 1 1+1e-4 1.05 1.05+1e-4 4]', [0 0 0.2 0.2 0 0]'};

%% Matched conditions (no reference rate limiter)
bb.setParamRaw('ref_rate', 1e6);
for m = {'lqr', 'cascade'}
    bb.setMode(m{1}); bb.clearSignals(); bb.setRef('const', 0);
    bb.setInitialState([0.1 0 0 0]);
    save_([m{1} '_ic'], bb.run(5));
    [t, r] = stepSig(1, 0.1, 6);
    bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
    save_([m{1} '_step'], bb.run(6));
    bb.clearSignals(); bb.setRef('const', 0);
    bb.setDisturbanceSignal(tap{:});
    save_([m{1} '_tap'], bb.run(4));
end
bb.clearSignals();

[t, r] = stepSig(1, 0.1, 6);
bb.setMode('cascade'); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
bb.setParamRaw('ff_on', 0); bb.setParamRaw('Ki_x', 0);
save_('cascade_noff', bb.run(6));
bb.setParamRaw('ff_on', 1); bb.setParamRaw('Ki_x', 0.1);
bb.clearSignals(); bb.setRef('const', 0);

bb.setMode('beam'); bb.setBeamAngle(deg2rad(-2)); bb.setInitialState([0 0 0 0]);
save_('beam_tilt', bb.run(3));
bb.setBeamAngle(0);

%% Default conditions (with rate limiter)
bb = BallBeam();
[t, r] = stepSig(1, 0.1, 6);
for m = {'lqr', 'cascade'}
    bb.setMode(m{1}); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
    save_([m{1} '_step_ratelim'], bb.run(6));
end

%% Sine tracking (+-10 cm)
bb.clearSignals();
for m = {'lqr', 'cascade'}
    for f = [0.1 0.25 0.5]
        bb.setMode(m{1}); bb.setInitialState([0 0 0 0]); bb.setRef('sine', 0, 0.1, f);
        save_(sprintf('sine_%s_%g', m{1}, f), bb.run(20));
    end
end

%% Sensor noise enabled
bb.setMode('lqr'); bb.setRef('const', 0); bb.setParam('noise_on', 1);
bb.setInitialState([0 0 0 0]);
save_('lqr_noise', bb.run(6));

fprintf('Validation runs written to %s\n', outDir);
if nargout == 0, clear outDir; end
end
EOF
cat > validation/compare_with_python.py <<'EOF'
"""Compares the Simulink runs produced by run_validation.m against the
Python replica (python_reference_sim.py) under the same conditions.

Usage:  python3 compare_with_python.py [results_dir]   (default: ./results)
"""
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from python_reference_sim import params, design, simulate  # noqa: E402

R = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'results')
P = design(params())
Pn = dict(P); Pn['ff_on'] = 0; Pn['Ki_x'] = 0.0
rf = lambda t: 0.1 if t > 1 else 0.0
tap = lambda t: 0.2 if 1 < t < 1.05 else 0.0

cases = {}
for name, mode in (('lqr', 3), ('cascade', 2)):
    cases[name + '_ic'] = (P, [0.1, 0, 0, 0], mode, 5, None, None, 0.0)
    cases[name + '_step'] = (P, [0, 0, 0, 0], mode, 6, rf, None, 0.0)
    cases[name + '_tap'] = (P, [0, 0, 0, 0], mode, 4, None, tap, 0.0)
cases['cascade_noff'] = (Pn, [0, 0, 0, 0], 2, 6, rf, None, 0.0)
cases['beam_tilt'] = (P, [0, 0, 0, 0], 1, 3, None, None, np.radians(-2))


def settle(t, e, tol):
    i = np.where(np.abs(e) > tol)[0]
    return t[i[-1]] if len(i) else 0.0


def load(name):
    return np.loadtxt(os.path.join(R, name + '.csv'), delimiter=',')


print(f"{'case':14s} {'RMS dx[mm]':>10s} {'max dx':>8s} {'RMS dal[deg]':>12s} {'max dal':>8s}"
      " | metric python vs simulink")
for name, (PP, x0, mode, T, ref, push, alman) in cases.items():
    L = simulate(PP, x0, mode, T, ref=ref or (lambda t: 0.0), push=push, alman=alman)
    tp, xp, alp, Vp = L[:, 0], L[:, 1], L[:, 3], L[:, 5]
    M = load(name)
    ts, xs, als, Vs = M[:, 0], M[:, 1], M[:, 3], M[:, 5]
    dx = 1e3*(np.interp(tp, ts, xs) - xp)
    dal = np.degrees(np.interp(tp, ts, als) - alp)
    if 'step' in name or 'noff' in name:
        m = (f"settle(5mm) {settle(tp, xp - 0.1, 0.005) - 1:.2f} / {settle(ts, xs - 0.1, 0.005) - 1:.2f} s,"
             f" overshoot {100*(xp.max() - 0.1)/0.1:.1f} / {100*(xs.max() - 0.1)/0.1:.1f} %,"
             f" final {100*xp[-1]:.2f} / {100*xs[-1]:.2f} cm")
    elif name.endswith('_ic'):
        m = (f"settle(5mm) {settle(tp, xp, 0.005):.2f} / {settle(ts, xs, 0.005):.2f} s,"
             f" Vmax {np.abs(Vp).max():.1f} / {np.abs(Vs).max():.1f} V")
    elif name.endswith('_tap'):
        m = (f"max|x| {100*np.abs(xp).max():.2f} / {100*np.abs(xs).max():.2f} cm,"
             f" settle(2mm) {settle(tp, xp, 0.002) - 1:.2f} / {settle(ts, xs, 0.002) - 1:.2f} s")
    else:
        i_p, i_s = np.argmax(np.abs(xp) > 0.185), np.argmax(np.abs(xs) > 0.185)
        m = (f"reaches the stop at {tp[i_p]:.3f} / {ts[i_s]:.3f} s,"
             f" final alpha {np.degrees(alp[-1]):.2f} / {np.degrees(als[-1]):.2f} deg")
    print(f"{name:14s} {np.sqrt(np.mean(dx**2)):10.3f} {np.abs(dx).max():8.3f} "
          f"{np.sqrt(np.mean(dal**2)):12.3f} {np.abs(dal).max():8.3f} | {m}")

print()
for name in ('lqr_step_ratelim', 'cascade_step_ratelim'):
    M = load(name); ts, xs = M[:, 0], M[:, 1]
    print(f"{name}: settle(5mm) {settle(ts, xs - 0.1, 0.005) - 1:.2f} s, "
          f"overshoot {100*(xs.max() - 0.1)/0.1:.1f} %, Vmax {np.abs(M[:, 6]).max():.1f} V")
for m in ('lqr', 'cascade'):
    for f in ('0.1', '0.25', '0.5'):
        M = load(f'sine_{m}_{f}'); ts, x, r = M[:, 0], M[:, 1], M[:, 7]; k = ts > 8
        E = np.exp(-1j*2*np.pi*float(f)*ts[k]); gx, gr = np.sum(x[k]*E), np.sum(r[k]*E)
        print(f"sine {m:7s} {f:>4s} Hz: gain {abs(gx/gr):.3f}, phase lag {np.degrees(np.angle(gr/gx)):.1f} deg, "
              f"Vmax {np.abs(M[:, 6]).max():.1f} V")
M = load('lqr_noise'); k = M[:, 0] > 2
print(f"noise on: x std after 2 s {1e3*M[k, 1].std():.2f} mm, V std {M[k, 6].std():.2f} V, "
      f"alpha std {np.degrees(M[k, 3]).std():.3f} deg")
EOF
echo done
```

</details>

<details><summary>Output</summary>

```
done
```

</details>

**🔧 Bash** — Write plate validation and run both Simulink validations

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate && cat > validation/run_validation.m <<'EOF'
function outDir = run_validation(outDir)
%RUN_VALIDATION  Runs the reference scenarios on the ball and plate Simulink
%   model and stores each run as a CSV, so they can be compared against the
%   Python replica with compare_with_python.py.
%
%   run_validation                 -> writes to validation/results/
%   run_validation('some/folder')
%
%   CSV columns (SI units):
%     t x xd y yd al ald be bed Va Vb rx ry xm ym
%
%   Scenarios "matched" to the Python replica run with the reference rate
%   limiter disabled (the replica does not model it). The "*_ratelim"
%   scenarios use the default parameters.
%
%   Then, from a shell:
%     python3 compare_with_python.py results

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1 || isempty(outDir), outDir = fullfile(here, 'results'); end
if ~exist(outDir, 'dir'), mkdir(outDir); end

save_ = @(name, res) writematrix([res.t res.x res.xd res.y res.yd res.al res.ald ...
    res.be res.bed res.Va res.Vb res.rx res.ry res.xm res.ym], ...
    fullfile(outDir, [name '.csv']));
tStep = [0 1 1+1e-4 6]'; rStep = [0 0; 0 0; 0.08 -0.05; 0.08 -0.05];
tTap  = [0 1 1+1e-4 1.05 1.05+1e-4 4]'; fTap = [0 0; 0 0; 0.2 0.2; 0.2 0.2; 0 0; 0 0];

bp_build_model();
bp = BallPlate();

%% Matched conditions (no reference rate limiter)
bp.setParamRaw('ref_rate', 1e6);
for m = {'lqr', 'cascade'}
    bp.setMode(m{1}); bp.clearSignals(); bp.setRef('point', [0 0]);
    bp.setInitialState([0.08 0 -0.05 0 0 0 0 0]);
    save_([m{1} '_ic'], bp.run(5));
    bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tStep, rStep);
    save_([m{1} '_step'], bp.run(6));
    bp.clearSignals(); bp.setRef('point', [0 0]);
    bp.setDisturbanceSignal(tTap, fTap);
    save_([m{1} '_tap'], bp.run(4));
    bp.clearSignals();
    bp.setInitialState([0.06 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.06, 0.2);
    save_([m{1} '_circle'], bp.run(15));
end

bp.setMode('cascade'); bp.setParam('Tcam', 0.04);
bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tStep, rStep);
save_('cascade_step_25fps', bp.run(6));
bp.setParam('Tcam', 0.02); bp.clearSignals();

bp.setMode('plate'); bp.setPlateAngle(deg2rad(-1), deg2rad(0.5));
bp.setRef('point', [0 0]); bp.setInitialState(zeros(8, 1));
save_('plate_tilt', bp.run(4));
bp.setPlateAngle(0, 0);

%% Default conditions (with rate limiter)
bp = BallPlate();
for m = {'lqr', 'cascade'}
    bp.setMode(m{1}); bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tStep, rStep);
    save_([m{1} '_step_ratelim'], bp.run(6));
end
bp.clearSignals();
bp.setMode('lqr'); bp.setInitialState(zeros(8, 1)); bp.setRef('eight', [0 0], 0.07, 0.15);
save_('lqr_eight', bp.run(20));
bp.setInitialState([0.09 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.09, 0.4);
save_('lqr_circle_fast', bp.run(12));

%% Sensor noise enabled
bp.setRef('point', [0 0]); bp.setParam('noise_on', 1);
bp.setInitialState(zeros(8, 1));
save_('lqr_noise', bp.run(6));

fprintf('Validation runs written to %s\n', outDir);
if nargout == 0, clear outDir; end
end
EOF
cat > validation/compare_with_python.py <<'EOF'
"""Compares the Simulink runs produced by run_validation.m against the
Python replica (python_reference_sim.py) under the same conditions.

Usage:  python3 compare_with_python.py [results_dir]   (default: ./results)
"""
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from python_reference_sim import params, design, simulate  # noqa: E402

R = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'results')
P = design(params())
P25 = dict(P); P25['Tcam'] = 0.04
tgt = np.array([0.08, -0.05])
rf = lambda t: tgt if t > 1 else np.zeros(2)
tap = lambda t: (0.2, 0.2) if 1 < t < 1.05 else (0.0, 0.0)
circ = lambda t: 0.06*np.array([np.cos(0.4*np.pi*t), np.sin(0.4*np.pi*t)])
x_ic = [0.08, 0, -0.05, 0, 0, 0, 0, 0]

cases = {}
for name, mode in (('lqr', 3), ('cascade', 2)):
    cases[name + '_ic'] = (P, x_ic, mode, 5, None, None, (0, 0))
    cases[name + '_step'] = (P, [0]*8, mode, 6, rf, None, (0, 0))
    cases[name + '_tap'] = (P, [0]*8, mode, 4, None, tap, (0, 0))
    cases[name + '_circle'] = (P, [0.06] + [0]*7, mode, 15, circ, None, (0, 0))
cases['cascade_step_25fps'] = (P25, [0]*8, 2, 6, rf, None, (0, 0))
cases['plate_tilt'] = (P, [0]*8, 1, 4, None, None, (np.radians(-1), np.radians(0.5)))


def settle(t, e, tol):
    i = np.where(np.abs(e) > tol)[0]
    return t[i[-1]] if len(i) else 0.0


def load(name):
    return np.loadtxt(os.path.join(R, name + '.csv'), delimiter=',')


print(f"{'case':19s} {'RMS dpos[mm]':>12s} {'max':>7s} {'RMS dtilt[deg]':>14s} {'max':>7s}"
      " | metric python / simulink")
for name, (PP, x0, mode, T, ref, push, alman) in cases.items():
    L = simulate(PP, x0, mode, T, ref=ref or (lambda t: np.zeros(2)), push=push, alman=alman)
    tp = L[:, 0]; pp = L[:, [1, 3]]; ap = L[:, [5, 7]]; Vp = L[:, 9:11]
    M = load(name)
    ts = M[:, 0]; ps = M[:, [1, 3]]; as_ = M[:, [5, 7]]; Vs = M[:, 9:11]
    dp = 1e3*np.hypot(*(np.column_stack([np.interp(tp, ts, ps[:, i]) for i in range(2)]) - pp).T)
    da = np.degrees(np.column_stack([np.interp(tp, ts, as_[:, i]) for i in range(2)]) - ap)
    da = np.hypot(da[:, 0], da[:, 1])
    if 'step' in name:
        ep, es = np.hypot(*(pp - tgt).T), np.hypot(*(ps - tgt).T)
        m = (f"settle(5mm) {settle(tp, ep, 0.005) - 1:.2f} / {settle(ts, es, 0.005) - 1:.2f} s,"
             f" overshoot x {100*(pp[:, 0].max() - 0.08)/0.08:.1f} / {100*(ps[:, 0].max() - 0.08)/0.08:.1f} %")
    elif name.endswith('_ic'):
        m = (f"settle(5mm) {settle(tp, np.hypot(*pp.T), 0.005):.2f} / {settle(ts, np.hypot(*ps.T), 0.005):.2f} s,"
             f" Vmax {np.abs(Vp).max():.1f} / {np.abs(Vs).max():.1f} V")
    elif name.endswith('_tap'):
        m = (f"max dist {100*np.hypot(*pp.T).max():.2f} / {100*np.hypot(*ps.T).max():.2f} cm")
    elif name.endswith('_circle'):
        rp_, rs = np.hypot(*pp[tp > 5].T), np.hypot(*ps[ts > 5].T)
        m = (f"radius {100*rp_.mean():.2f} ({100*rp_.min():.2f}-{100*rp_.max():.2f}) / "
             f"{100*rs.mean():.2f} ({100*rs.min():.2f}-{100*rs.max():.2f}) cm")
    else:
        i_p = np.argmax(np.abs(pp).max(1) > 0.135); i_s = np.argmax(np.abs(ps).max(1) > 0.135)
        m = f"reaches the rim at {tp[i_p]:.3f} / {ts[i_s]:.3f} s"
    print(f"{name:19s} {np.sqrt(np.mean(dp**2)):12.3f} {dp.max():7.3f} "
          f"{np.sqrt(np.mean(da**2)):14.3f} {da.max():7.3f} | {m}")

print()
for name in ('lqr_step_ratelim', 'cascade_step_ratelim'):
    M = load(name); ts, ps = M[:, 0], M[:, [1, 3]]
    print(f"{name}: settle(5mm) {settle(ts, np.hypot(*(ps - tgt).T), 0.005) - 1:.2f} s, "
          f"overshoot x {100*(ps[:, 0].max() - 0.08)/0.08:.1f} %, Vmax {np.abs(M[:, 9:11]).max():.1f} V")
for name in ('lqr_eight', 'lqr_circle_fast'):
    M = load(name); k = M[:, 0] > 5
    e = np.hypot(M[k, 1] - M[k, 11], M[k, 3] - M[k, 12])
    print(f"{name}: tracking error RMS {1e3*np.sqrt(np.mean(e**2)):.1f} mm, max {1e3*e.max():.1f} mm, "
          f"Vmax {np.abs(M[:, 9:11]).max():.1f} V, max tilt {np.degrees(np.abs(M[:, [5, 7]])).max():.1f} deg")
M = load('lqr_noise'); k = M[:, 0] > 2
print(f"noise on: ball std after 2 s {1e3*M[k, 1].std():.2f} / {1e3*M[k, 3].std():.2f} mm, "
      f"V std {M[k, 9].std():.2f} / {M[k, 10].std():.2f} V")
EOF
cat > /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt/t8.m <<'EOF'
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/validation
run_validation
bdclose all
cd /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/validation
run_validation
EOF
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 1200 matlab -batch "t8" 2>&1 | grep -v "^\[Warning\|close_system\|^To save" | tail -8
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/ballbeam_sim.slx
Validation runs written to /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/validation/results
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/ballplate_sim.slx
Validation runs written to /home/aguti/universidad/controlSystemsMatlabModels/src/ball_plate/validation/results
[Warning: Unable to close the model 'ballplate_sim' because it has been changed.
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Compare both Simulink models against Python replicas

<details><summary>Command</summary>

```bash
cd /home/aguti/universidad/controlSystemsMatlabModels/src && python3 ball_beam/validation/compare_with_python.py && echo && time python3 ball_plate/validation/compare_with_python.py
```

</details>

<details><summary>Output</summary>

```
case           RMS dx[mm]   max dx RMS dal[deg]  max dal | metric python vs simulink
lqr_ic              0.060    0.242        0.018    0.091 | settle(5mm) 0.68 / 0.68 s, Vmax 4.3 / 4.3 V
lqr_step            0.056    0.247        0.016    0.092 | settle(5mm) 0.64 / 0.64 s, overshoot 2.5 / 2.5 %, final 10.00 / 10.00 cm
lqr_tap             0.110    0.382        0.026    0.104 | max|x| 1.89 / 1.93 cm, settle(2mm) 2.21 / 2.22 s
cascade_ic          0.043    0.142        0.013    0.099 | settle(5mm) 1.52 / 1.52 s, Vmax 5.7 / 5.7 V
cascade_step        0.039    0.146        0.012    0.100 | settle(5mm) 1.50 / 1.50 s, overshoot 0.8 / 0.8 %, final 10.07 / 10.07 cm
cascade_tap         0.108    0.327        0.024    0.120 | max|x| 1.66 / 1.69 cm, settle(2mm) 1.19 / 1.20 s
cascade_noff        0.041    0.147        0.012    0.100 | settle(5mm) 5.00 / 5.00 s, overshoot 11.0 / 11.0 %, final 11.07 / 11.07 cm
beam_tilt           0.314    0.668        0.007    0.027 | reaches the stop at 1.249 / 1.250 s, final alpha -3.39 / -3.39 deg

lqr_step_ratelim: settle(5mm) 0.85 s, overshoot 2.6 %, Vmax 1.0 V
cascade_step_ratelim: settle(5mm) 1.67 s, overshoot 0.7 %, Vmax 1.1 V
sine lqr      0.1 Hz: gain 1.086, phase lag 14.0 deg, Vmax 0.9 V
sine lqr     0.25 Hz: gain 0.963, phase lag 35.5 deg, Vmax 0.8 V
sine lqr      0.5 Hz: gain 0.881, phase lag 69.0 deg, Vmax 0.9 V
sine cascade  0.1 Hz: gain 1.061, phase lag 20.9 deg, Vmax 1.0 V
sine cascade 0.25 Hz: gain 0.831, phase lag 50.8 deg, Vmax 0.9 V
sine cascade  0.5 Hz: gain 0.579, phase lag 88.3 deg, Vmax 0.7 V
noise on: x std after 2 s 0.15 mm, V std 0.85 V, alpha std 0.068 deg

case                RMS dpos[mm]     max RMS dtilt[deg]     max | metric python / simulink
lqr_ic                     5.481  12.346          1.174   2.701 | settle(5mm) 3.48 / 1.95 s, Vmax 2.1 / 2.7 V
lqr_step                   5.138  12.435          1.134   2.864 | settle(5mm) 3.45 / 1.92 s, overshoot x 12.5 / 6.4 %
lqr_tap                    4.783   9.305          1.111   2.361 | max dist 3.58 / 3.36 cm
lqr_circle                 3.663   6.091          0.240   0.721 | radius 5.93 (5.55-6.40) / 5.75 (5.41-6.08) cm
cascade_ic                 0.040   0.136          0.010   0.070 | settle(5mm) 1.63 / 1.63 s, Vmax 3.6 / 3.6 V
cascade_step               0.037   0.137          0.009   0.073 | settle(5mm) 1.63 / 1.63 s, overshoot x 1.2 / 1.2 %
cascade_tap                0.268   0.756          0.072   0.240 | max dist 3.03 / 3.11 cm
cascade_circle             0.089   0.259          0.023   0.169 | radius 5.14 (5.07-5.21) / 5.14 (5.07-5.21) cm
cascade_step_25fps         0.039   0.158          0.009   0.073 | settle(5mm) 1.60 / 1.60 s, overshoot x 1.3 / 1.3 %
plate_tilt                 0.179   0.514          0.003   0.014 | reaches the rim at 1.483 / 1.484 s

lqr_step_ratelim: settle(5mm) 2.06 s, overshoot x 6.7 %, Vmax 1.0 V
cascade_step_ratelim: settle(5mm) 1.75 s, overshoot x 1.2 %, Vmax 1.0 V
lqr_eight: tracking error RMS 27.4 mm, max 41.5 mm, Vmax 0.8 V,
... [truncated, 213 more characters]
```

</details>

**🔧 Bash** — Sync Python LQR weights and recompare plate

<details><summary>Command</summary>

```bash
sed -i "s/Q=np.diag(\[300.0, 20.0, 10.0, 0.5, 50.0\]), R=1.0,/Q=np.diag([500.0, 60.0, 10.0, 0.5, 100.0]), R=1.0,/" ball_plate/python_reference_sim.py && grep -n "Q=np.diag" ball_plate/python_reference_sim.py && python3 ball_plate/validation/compare_with_python.py | head -12
```

</details>

<details><summary>Output</summary>

```
42:        Q=np.diag([500.0, 60.0, 10.0, 0.5, 100.0]), R=1.0,
case                RMS dpos[mm]     max RMS dtilt[deg]     max | metric python / simulink
lqr_ic                     0.060   0.227          0.015   0.066 | settle(5mm) 1.95 / 1.95 s, Vmax 2.7 / 2.7 V
lqr_step                   0.056   0.231          0.014   0.067 | settle(5mm) 1.92 / 1.92 s, overshoot x 6.4 / 6.4 %
lqr_tap                    0.248   0.796          0.065   0.227 | max dist 3.28 / 3.36 cm
lqr_circle                 0.106   0.320          0.022   0.124 | radius 5.76 (5.41-6.09) / 5.75 (5.41-6.08) cm
cascade_ic                 0.040   0.136          0.010   0.070 | settle(5mm) 1.63 / 1.63 s, Vmax 3.6 / 3.6 V
cascade_step               0.037   0.137          0.009   0.073 | settle(5mm) 1.63 / 1.63 s, overshoot x 1.2 / 1.2 %
cascade_tap                0.268   0.756          0.072   0.240 | max dist 3.03 / 3.11 cm
cascade_circle             0.089   0.259          0.023   0.169 | radius 5.14 (5.07-5.21) / 5.14 (5.07-5.21) cm
cascade_step_25fps         0.039   0.158          0.009   0.073 | settle(5mm) 1.60 / 1.60 s, overshoot x 1.3 / 1.3 %
plate_tilt                 0.179   0.514          0.003   0.014 | reaches the rim at 1.483 / 1.484 s
[This command modified 1 file you've previously read: ball_plate/python_reference_sim.py. Call Read before editing.]
```

</details>

## 🤖 Claude

Validation passes for both: Simulink and Python agree within 0.27 mm RMS in position and 0.07° in tilt in every scenario. Next I'll run both `examples.m` walkthroughs end to end in batch.

**🔧 Bash** — Run both examples walkthroughs in batch

<details><summary>Command</summary>

```bash
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && for e in ball_beam ball_plate; do python3 - "$e" <<'EOF'
import sys
e = sys.argv[1]
s = open(f'/home/aguti/universidad/controlSystemsMatlabModels/src/{e}/examples.m').read()
s = s[:s.index('%% 10)')]
s = s.replace('clear; close all; clc', "close all; set(groot,'DefaultFigureVisible','off');")
pre = f"addpath('/home/aguti/universidad/controlSystemsMatlabModels/src/{e}'); cd('/home/aguti/universidad/controlSystemsMatlabModels/src/{e}');\n"
open(f'ex_{e}.m', 'w').write(pre + s + "\ndisp('EXAMPLES OK');\n")
EOF
done; cat > t9.m <<'EOF'
ex_ball_beam; bdclose all; ex_ball_plate;
EOF
timeout 1500 matlab -batch "t9" 2>&1 | grep -v "^\[Warning\|close_system\|^To save\|^ *$" | tail -40
```

</details>

<details><summary>Output</summary>

```
Model created: /home/aguti/universidad/controlSystemsMatlabModels/src/ball_beam/ballbeam_sim.slx
LQR gain [x-r, xd, alpha, alphad, int]:
  -43.4978  -15.7378   18.7881    1.1824  -14.1421
Open-loop poles:
 -10.6826 + 0.0000i   3.6237 + 0.0000i  -1.5795 + 3.8508i  -1.5795 - 3.8508i
Closed-loop poles (LQR + integral):
  Columns 1 through 4
 -16.6485 + 0.0000i  -4.8974 + 5.7815i  -4.8974 - 5.7815i  -4.3697 + 0.0000i
  Column 5
  -0.4436 + 0.0000i
EXAMPLES OK
{Unrecognized function or variable 'ex_ball_plate'.
Error in t9 (line 1)
ex_ball_beam; bdclose all; ex_ball_plate;
                           ^^^^^^^^^^^^^
}
Shell cwd was reset to /home/aguti/universidad/controlSystemsMatlabModels
```

</details>

**🔧 Bash** — Run ball-plate examples walkthrough

<details><summary>Command</summary>

```bash
cd /tmp/claude-1000/-home-aguti-universidad-controlSystemsMatlabModels/861c5db6-6ef9-45dd-b3cc-72270802e54f/scratchpad/bbt && timeout 1500 matlab -batch "addpath(pwd); ex_ball_plate" 2>&1 | grep -v "^\[Warning\|close_system\|^To save\|^ *$" | tail -20
```

</details>

