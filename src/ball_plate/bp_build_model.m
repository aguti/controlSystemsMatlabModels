function mdl = bp_build_model(mdl)
%BP_BUILD_MODEL  Generates the Simulink model of the ball and plate.
%
%   bp_build_model            -> creates and saves 'ballplate_sim.slx' in this folder
%
%   Model structure (top level):
%
%     cmd_ref ─┐                         cmd_ctrl ─┐
%     ref_ext ─┼─► [Reference] ── r ───────────────┼─► [Controller] ─► (+) ─► [Amplifier] ► [Plant] ─┐
%     Clock ───┘                                   │                 u_ext ┘     cmd_dist,d_ext ┘    │
%                                       y_meas ◄───┴──────────────── [Sensors] ◄─────────────────────┘
%
%   Sensors: overhead camera for the ball (frame period Tcam, latency
%   cam_delay frames, pixel quantization) and encoders on both plate axes.
%
%   Blocks modified LIVE from code/GUI (top level):
%     cmd_ctrl  Constant [mode enable Va_manual Vb_manual alpha_manual beta_manual]
%     cmd_ref   Constant [type cx cy amplitude frequency]
%     cmd_dist  Constant [Fx Fy] disturbance force on the ball [N]
%   Time signals from the workspace (read at start):
%     u_ext   [t Va Vb]   additional motor voltages
%     ref_ext [t rx ry]   external reference (type 4)
%     d_ext   [t Fx Fy]   scheduled disturbance force on the ball
%   Telemetry ('telemetry' block, 23 signals, saved in out.tel):
%     [x xd y yd al ald be bed | x_cam y_cam al_meas be_meas |
%      Va_cmd Vb_cmd Va Vb | rx ry | mode al_ref be_ref Ix Iy]

if nargin < 1 || isempty(mdl), mdl = 'ballplate_sim'; end
here = fileparts(mfilename('fullpath'));

% Variables required in the base workspace
P = bp_design(bp_params());
assignin('base', 'P', P);
for v = {'u_ext', 'ref_ext', 'd_ext'}
    if ~evalin('base', sprintf('exist(''%s'',''var'')', v{1}))
        assignin('base', v{1}, [0 0 0; 1 0 0]);
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
    'if ~exist(''P'',''var''), P = bp_design(bp_params()); end; ' ...
    'if ~exist(''u_ext'',''var''), u_ext = [0 0 0; 1 0 0]; end; ' ...
    'if ~exist(''ref_ext'',''var''), ref_ext = [0 0 0; 1 0 0]; end; ' ...
    'if ~exist(''d_ext'',''var''), d_ext = [0 0 0; 1 0 0]; end;']);
set_param(mdl, 'StartFcn', 'BallPlate.onModelStart(bdroot);');
set_param(mdl, 'StopFcn',  'BallPlate.onModelStop(bdroot);');

%% ---------------- Subsystem: Reference ----------------
S = sub(mdl, 'Reference', [190 55 310 175], {'t', 'cmd', 'ext'}, {'r'});
blk([S '/Generator'], 'simulink/User-Defined Functions/MATLAB Function', [130 40 260 160]);
setScript([S '/Generator'], fullfile(here, 'bp_ref_block.m'), {});
blk([S '/Rate limiter'], 'simulink/Discontinuities/Rate Limiter', [310 85 360 115], ...
    'RisingSlewLimit', 'P.ref_rate', 'FallingSlewLimit', '-P.ref_rate');
blk([S '/Range limit'], 'simulink/Discontinuities/Saturation', [400 85 450 115], ...
    'UpperLimit', 'P.x_ref_max', 'LowerLimit', '-P.x_ref_max');
ln(S, 't/1', 'Generator/1'); ln(S, 'cmd/1', 'Generator/2'); ln(S, 'ext/1', 'Generator/3');
ln(S, 'Generator/1', 'Rate limiter/1');
ln(S, 'Rate limiter/1', 'Range limit/1');
ln(S, 'Range limit/1', 'r/1');

%% ---------------- Subsystem: Controller ----------------
S = sub(mdl, 'Controller', [420 215 560 335], {'y_meas', 'r', 'cmd'}, {'V', 'info'});
blk([S '/ZOH r'], 'simulink/Discrete/Zero-Order Hold', [110 95 140 125], 'SampleTime', 'P.Ts');
blk([S '/Control law'], 'simulink/User-Defined Functions/MATLAB Function', [200 40 340 160]);
setScript([S '/Control law'], fullfile(here, 'bp_controller_block.m'), {'P'});
ln(S, 'y_meas/1', 'Control law/1');
ln(S, 'r/1', 'ZOH r/1'); ln(S, 'ZOH r/1', 'Control law/2');
ln(S, 'cmd/1', 'Control law/3');
ln(S, 'Control law/1', 'V/1'); ln(S, 'Control law/2', 'info/1');

%% ---------------- Subsystem: Amplifier ----------------
S = sub(mdl, 'Amplifier', [700 240 820 300], {'V_cmd'}, {'V_act'});
blk([S '/Saturation'], 'simulink/Discontinuities/Saturation', [270 35 320 65], ...
    'UpperLimit', 'P.Vmax', 'LowerLimit', '-P.Vmax');
ln(S, 'V_cmd/1', 'Saturation/1');
ln(S, 'Saturation/1', 'V_act/1');

%% ---------------- Subsystem: Plant ----------------
S = sub(mdl, 'Plant', [920 240 1040 360], {'V', 'Fd'}, {'s'});
blk([S '/Dynamics'], 'simulink/User-Defined Functions/MATLAB Function', [160 30 300 150]);
setScript([S '/Dynamics'], fullfile(here, 'bp_plant_block.m'), {'P'});
blk([S '/Integrator'], 'simulink/Continuous/Integrator', [360 75 400 105], ...
    'InitialCondition', 'P.x0');
ln(S, 'Integrator/1', 'Dynamics/1');
ln(S, 'V/1', 'Dynamics/2'); ln(S, 'Fd/1', 'Dynamics/3');
ln(S, 'Dynamics/1', 'Integrator/1');
ln(S, 'Integrator/1', 's/1');

%% ---------------- Subsystem: Sensors ----------------
S = sub(mdl, 'Sensors', [920 450 1040 510], {'s'}, {'y_meas'});
sel1 = {'NumberOfDimensions', '1', 'IndexOptions', 'Index vector (dialog)', 'InputPortWidth', '8'};
% camera: ball position
blk([S '/Ball xy'], 'simulink/Signal Routing/Selector', [90 25 130 55], sel1{:}, 'Indices', '[1 3]');
blk([S '/Noise cam'], 'simulink/Sources/Random Number', [90 170 120 200], ...
    'Mean', '[0 0]', 'Variance', '[1 1]', 'Seed', '[23341 50923]', 'SampleTime', 'P.Tcam');
blk([S '/sigma cam'], 'simulink/Math Operations/Gain', [150 170 200 200], 'Gain', 'P.noise_on*P.noise_cam');
blk([S '/Sum cam'], 'simulink/Math Operations/Sum', [170 30 190 50], 'Inputs', '++');
blk([S '/Pixels'], 'simulink/Discontinuities/Quantizer', [220 25 260 55], 'QuantizationInterval', 'P.res_cam');
blk([S '/Frame rate'], 'simulink/Discrete/Zero-Order Hold', [290 25 320 55], 'SampleTime', 'P.Tcam');
blk([S '/Latency'], 'simulink/Discrete/Delay', [350 25 390 55], ...
    'DelayLength', 'P.cam_delay', 'SampleTime', 'P.Tcam', ...
    'InitialCondition', 'reshape(repmat(round(P.x0([1 3])/P.res_cam)*P.res_cam, 1, max(1, P.cam_delay)), 2, 1, [])');
    % (the input is a 2x1 signal: the Delay block wants a 2x1xcam_delay initial condition)
% encoders: plate angles
blk([S '/Plate angles'], 'simulink/Signal Routing/Selector', [90 95 130 125], sel1{:}, 'Indices', '[5 7]');
blk([S '/Noise enc'], 'simulink/Sources/Random Number', [90 240 120 270], ...
    'Mean', '[0 0]', 'Variance', '[1 1]', 'Seed', '[61277 7741]', 'SampleTime', 'P.Ts');
blk([S '/sigma enc'], 'simulink/Math Operations/Gain', [150 240 200 270], 'Gain', 'P.noise_on*P.noise_al');
blk([S '/Sum enc'], 'simulink/Math Operations/Sum', [170 100 190 120], 'Inputs', '++');
blk([S '/Encoders'], 'simulink/Discontinuities/Quantizer', [220 95 260 125], 'QuantizationInterval', 'P.res_al');
blk([S '/Mux'], 'simulink/Signal Routing/Mux', [420 30 425 120], 'Inputs', '2');
blk([S '/Sampling'], 'simulink/Discrete/Zero-Order Hold', [460 60 490 90], 'SampleTime', 'P.Ts');
ln(S, 's/1', 'Ball xy/1'); ln(S, 's/1', 'Plate angles/1');
ln(S, 'Ball xy/1', 'Sum cam/1');
ln(S, 'Noise cam/1', 'sigma cam/1'); ln(S, 'sigma cam/1', 'Sum cam/2');
ln(S, 'Sum cam/1', 'Pixels/1'); ln(S, 'Pixels/1', 'Frame rate/1');
ln(S, 'Frame rate/1', 'Latency/1'); ln(S, 'Latency/1', 'Mux/1');
ln(S, 'Plate angles/1', 'Sum enc/1');
ln(S, 'Noise enc/1', 'sigma enc/1'); ln(S, 'sigma enc/1', 'Sum enc/2');
ln(S, 'Sum enc/1', 'Encoders/1'); ln(S, 'Encoders/1', 'Mux/2');
ln(S, 'Mux/1', 'Sampling/1'); ln(S, 'Sampling/1', 'y_meas/1');

%% ---------------- Command panel (top level) ----------------
blk([mdl '/Clock'], 'simulink/Sources/Clock', [40 50 70 80]);
blk([mdl '/cmd_ref'], 'simulink/Sources/Constant', [20 100 130 130], 'Value', '[0 0 0 0.06 0.2]');
blk([mdl '/ref_ext'], 'simulink/Sources/From Workspace', [20 150 130 180], ...
    'VariableName', 'ref_ext', 'Interpolate', 'on', ...
    'OutputAfterFinalValue', 'Holding final value', 'SampleTime', '0');
blk([mdl '/cmd_ctrl'], 'simulink/Sources/Constant', [220 300 330 330], 'Value', '[3 1 0 0 0 0]');
blk([mdl '/u_ext'], 'simulink/Sources/From Workspace', [470 380 580 410], ...
    'VariableName', 'u_ext', 'Interpolate', 'on', ...
    'OutputAfterFinalValue', 'Setting to zero', 'SampleTime', '0');
blk([mdl '/SumV'], 'simulink/Math Operations/Sum', [620 255 640 285], 'Inputs', '++');
blk([mdl '/cmd_dist'], 'simulink/Sources/Constant', [700 360 790 390], 'Value', '[0 0]');
blk([mdl '/d_ext'], 'simulink/Sources/From Workspace', [700 410 790 440], ...
    'VariableName', 'd_ext', 'Interpolate', 'on', ...
    'OutputAfterFinalValue', 'Setting to zero', 'SampleTime', '0');
blk([mdl '/SumD'], 'simulink/Math Operations/Sum', [840 370 860 400], 'Inputs', '++');

ln(mdl, 'Clock/1', 'Reference/1');
ln(mdl, 'cmd_ref/1', 'Reference/2');
ln(mdl, 'ref_ext/1', 'Reference/3');
ln(mdl, 'Sensors/1', 'Controller/1');
ln(mdl, 'Reference/1', 'Controller/2');
ln(mdl, 'cmd_ctrl/1', 'Controller/3');
ln(mdl, 'Controller/1', 'SumV/1');
ln(mdl, 'u_ext/1', 'SumV/2');
ln(mdl, 'SumV/1', 'Amplifier/1');
ln(mdl, 'Amplifier/1', 'Plant/1');
ln(mdl, 'cmd_dist/1', 'SumD/1');
ln(mdl, 'd_ext/1', 'SumD/2');
ln(mdl, 'SumD/1', 'Plant/2');
ln(mdl, 'Plant/1', 'Sensors/1');

%% ---------------- Telemetry, logging and Scope ----------------
blk([mdl '/Mux tel'], 'simulink/Signal Routing/Mux', [1130 200 1135 560], 'Inputs', '6');
blk([mdl '/telemetry'], 'simulink/Math Operations/Gain', [1180 365 1230 395], 'Gain', '1');
blk([mdl '/tel'], 'simulink/Sinks/To Workspace', [1290 360 1380 400], ...
    'VariableName', 'tel', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
ln(mdl, 'Plant/1', 'Mux tel/1');
ln(mdl, 'Sensors/1', 'Mux tel/2');
ln(mdl, 'SumV/1', 'Mux tel/3');
ln(mdl, 'Amplifier/1', 'Mux tel/4');
ln(mdl, 'Reference/1', 'Mux tel/5');
ln(mdl, 'Controller/2', 'Mux tel/6');
ln(mdl, 'Mux tel/1', 'telemetry/1');
ln(mdl, 'telemetry/1', 'tel/1');

sel = {'x rx', '[1 17]', 470; 'y ry', '[3 18]', 530; 'alpha beta', '[5 7]', 590; 'Va Vb', '[15 16]', 650};
for k = 1:size(sel, 1)
    y0 = sel{k, 3};
    blk([mdl '/Sel ' sel{k,1}], 'simulink/Signal Routing/Selector', [1290 y0 1340 y0+30], ...
        'NumberOfDimensions', '1', 'IndexOptions', 'Index vector (dialog)', ...
        'Indices', sel{k,2}, 'InputPortWidth', '23');
end
blk([mdl '/Scope'], 'simulink/Sinks/Scope', [1400 470 1440 680]);
trySet([mdl '/Scope'], 'NumInputPorts', '4');
for k = 1:size(sel, 1)
    ln(mdl, 'telemetry/1', ['Sel ' sel{k,1} '/1']);
    ln(mdl, ['Sel ' sel{k,1} '/1'], sprintf('Scope/%d', k));
end

% Pacing (real time) disabled by default; BallPlate.start() enables it
trySet(mdl, 'EnablePacing', 'off');

save_system(mdl, f);
open_system(mdl);
fprintf('Model created: %s\n', f);
end

%% ======================= local helpers =======================
function S = sub(mdl, name, pos, ins, outs)
S = [mdl '/' name];
add_block('built-in/Subsystem', S, 'Position', pos);
for i = 1:numel(ins)
    add_block('built-in/Inport', [S '/' ins{i}], ...
        'Position', [20 40+70*(i-1) 50 54+70*(i-1)]);
end
for i = 1:numel(outs)
    add_block('built-in/Outport', [S '/' outs{i}], ...
        'Position', [560 60+70*(i-1) 590 74+70*(i-1)]);
end
end

function blk(path, lib, pos, varargin)
add_block(lib, path, 'Position', pos, varargin{:});
end

function ln(sys, src, dst)
add_line(sys, src, dst, 'autorouting', 'on');
end

function setScript(blkPath, file, paramNames)
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blkPath);
ch.Script = fileread(file);
for k = 1:numel(paramNames)
    d = ch.find('-isa', 'Stateflow.Data', 'Name', paramNames{k});
    d.Scope = 'Parameter';
end
end

function trySet(obj, varargin)
try
    set_param(obj, varargin{:});
catch err
    warning('bp_build_model:param', 'Could not set %s: %s', varargin{1}, err.message);
end
end
