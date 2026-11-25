classdef BallPlate < handle
%BALLPLATE  Code interface for the Simulink model of the ball and plate.
%
%   Units: metres and radians (x, y = ball position; alpha, beta = plate tilts).
%
%   bp = BallPlate();                  % loads (or generates) ballplate_sim.slx
%
%   --- Batch runs (fast, not real time) ---
%   bp.setInitialState([0.08 0 -0.05 0 0 0 0 0]);  % [x xd y yd al ald be bed]
%   bp.setMode('lqr');                 % 'open','plate','cascade','lqr' (or 0..3)
%   bp.setRef('circle', [0 0], 0.06, 0.2);   % type, centre [m], amplitude [m], freq [Hz]
%   res = bp.run(10);                  % simulates 10 s and returns a struct of signals
%   bp_plot_results(res); bp.animate(res);
%
%   --- Live execution (real time, commands while running) ---
%   bp.start();                        % starts with StopTime = inf and 1x pacing
%   bp.setRef('point', [0.05 0.05]);   % move the target
%   bp.setVoltage(1, 0);               % manual voltages [V] (added to the controller's)
%   bp.setPlateAngle(0.05, 0);         % plate tilts for mode 'plate' [rad]
%   bp.push([0.2 0], 0.05);            % tap: 0.2 N on the ball along +x for 0.05 s
%   bp.setParam('Q', diag([1000 60 10 0.5 100]));   % recomputes the LQR, live
%   bp.stop(); res = bp.lastResult();
%
%   --- Time signals (read at start) ---
%   bp.setRefSignal(t, rxy)           external reference, rxy = [rx ry] (N x 2) [m]
%   bp.setVoltageSignal(t, U)         additional voltages, U = [Va Vb] (N x 2)
%   bp.setDisturbanceSignal(t, F)     scheduled force on the ball, F = [Fx Fy] (N x 2)
%
%   --- Live telemetry ---
%   bp.addTelemetryCallback(@(t, d) disp(d(1:3:4)));   % d = 23-signal vector
%   Indices: BallPlate.TEL.x, .xd, .y, .yd, .al, .ald, .be, .bed, .xm, .ym,
%            .alm, .bem, .Vca, .Vcb, .Va, .Vb, .rx, .ry, .mode, .alr, .ber, .Ix, .Iy

    properties
        P                       % parameter struct (bp_params + bp_design)
        Model = 'ballplate_sim'
        TelemetryRate = 30      % maximum rate [Hz] at which live callbacks are called
        GuiLoad = 0.4           % maximum fraction of wall time spent in live callbacks
        PacingRate = 1          % 1 = real time, 0.5 = slow motion, 2 = double
    end

    properties (SetAccess = private)
        Last = zeros(23,1)      % last telemetry received
        LastTime = 0
        CmdCtrl = [3 1 0 0 0 0] % [mode enable Va Vb alpha_manual beta_manual]
        CmdRef  = [0 0 0 0.06 0.2]  % [type cx cy amplitude frequency]
        Lin                     % linear models (.x and .y axes)
    end

    properties (Access = private)
        telCallbacks = {}
        stopCallbacks = {}
        listener = []
        tick
        cbPeriod = 0
        batch = false
        pushTimer = []
    end

    properties (Constant)
        TEL = struct('x',1,'xd',2,'y',3,'yd',4,'al',5,'ald',6,'be',7,'bed',8, ...
                     'xm',9,'ym',10,'alm',11,'bem',12, ...
                     'Vca',13,'Vcb',14,'Va',15,'Vb',16,'rx',17,'ry',18, ...
                     'mode',19,'alr',20,'ber',21,'Ix',22,'Iy',23)
        MODES = {'open','plate','cascade','lqr'}
        REFTYPES = {'point','circle','square','eight','external'}
    end

    %% ================== Construction ==================
    methods
        function obj = BallPlate(varargin)
            here = fileparts(mfilename('fullpath'));
            addpath(here);
            if nargin >= 1, obj.Model = varargin{1}; end
            obj.P = bp_params();
            [obj.P, obj.Lin] = bp_design(obj.P);
            obj.pushParams();
            for v = {'u_ext', 'ref_ext', 'd_ext'}
                assignin('base', v{1}, [0 0 0; 1 0 0]);
            end
            if ~bdIsLoaded(obj.Model)
                if exist(fullfile(here, [obj.Model '.slx']), 'file')
                    load_system(fullfile(here, [obj.Model '.slx']));
                else
                    bp_build_model(obj.Model);
                end
            end
            obj.tick = tic;
            setappdata(0, 'BallPlateInstance', obj);
            obj.applyCmd();
        end

        function delete(obj)
            try, if obj.isRunning(), obj.stop(); end, catch, end
            try, if ~isempty(obj.pushTimer) && isvalid(obj.pushTimer), stop(obj.pushTimer); delete(obj.pushTimer); end, catch, end
        end
    end

    %% ================== Commands (valid live) ==================
    methods
        function setMode(obj, m)
            %SETMODE  0/'open' 1/'plate' 2/'cascade' 3/'lqr'
            if ischar(m) || isstring(m)
                m = find(strcmpi(obj.MODES, m)) - 1;
                assert(~isempty(m), 'Unknown mode');
            end
            obj.CmdCtrl(1) = m; obj.applyCmd();
        end

        function enable(obj, tf)
            obj.CmdCtrl(2) = double(logical(tf)); obj.applyCmd();
        end

        function setVoltage(obj, ua, ub)
            %SETVOLTAGE  Manual voltages [V] of motors A and B, added to the controller's.
            if nargin < 3, ub = 0; end
            obj.CmdCtrl(3:4) = max(min([ua ub], obj.P.Vmax), -obj.P.Vmax); obj.applyCmd();
        end

        function setPlateAngle(obj, al, be)
            %SETPLATEANGLE  Plate tilt references [rad] used in mode 'plate'.
            obj.CmdCtrl(5:6) = max(min([al be], obj.P.al_max), -obj.P.al_max); obj.applyCmd();
        end

        function setRef(obj, type, centre, amp, freq)
            %SETREF  setRef(type, [cx cy], amplitude, frequency)   (positions in m)
            %   type: 'point' | 'circle' | 'square' | 'eight' | 'external' (or 0..4)
            if ischar(type) || isstring(type)
                type = find(strcmpi(obj.REFTYPES, type)) - 1;
                assert(~isempty(type), 'Unknown reference type');
            end
            if nargin < 3 || isempty(centre), centre = obj.CmdRef(2:3); end
            if nargin < 4, amp = obj.CmdRef(4); end
            if nargin < 5, freq = obj.CmdRef(5); end
            obj.CmdRef = [type centre(:).' amp freq]; obj.applyCmd();
        end

        function push(obj, F, dur)
            %PUSH  Tap on the ball (live). F = [Fx Fy] [N], dur [s].
            if nargin < 2, F = [0.2 0]; end
            if nargin < 3, dur = 0.05; end
            set_param([obj.Model '/cmd_dist'], 'Value', mat2str(F(:).', 6));
            if ~isempty(obj.pushTimer) && isvalid(obj.pushTimer)
                stop(obj.pushTimer); delete(obj.pushTimer);
            end
            obj.pushTimer = timer('StartDelay', round(dur/obj.PacingRate*1000)/1000, ...
                'ExecutionMode', 'singleShot', 'TimerFcn', @(~,~) obj.clearPush());
            start(obj.pushTimer);
        end

        function setParam(obj, name, value)
            %SETPARAM  Changes a parameter; recomputes derived values and the LQR, live.
            assert(isfield(obj.P, name), 'Unknown parameter: %s', name);
            obj.P.(name) = value;
            [obj.P, obj.Lin] = bp_design(obj.P);
            obj.pushParams();
            obj.refresh();
        end

        function setParamRaw(obj, name, value)
            %SETPARAMRAW  Changes a parameter WITHOUT recomputing the gains.
            %   Useful for robustness tests (true plant ~= nominal) or to
            %   impose gains by hand: bp.setParamRaw('Kx', [...]).
            %   Derived quantities (inertias, kv) ARE updated.
            assert(isfield(obj.P, name), 'Unknown parameter: %s', name);
            obj.P.(name) = value;
            obj.P = bp_derived(obj.P);
            obj.pushParams();
            obj.refresh();
        end

        function setParams(obj, S)
            %SETPARAMS  Several at once: bp.setParams(struct('m',0.03,'Kp_x',2))
            f = fieldnames(S);
            for k = 1:numel(f)
                assert(isfield(obj.P, f{k}), 'Unknown parameter: %s', f{k});
                obj.P.(f{k}) = S.(f{k});
            end
            [obj.P, obj.Lin] = bp_design(obj.P);
            obj.pushParams(); obj.refresh();
        end

        function setInitialState(obj, s0)
            %SETINITIALSTATE  [x xd y yd alpha alphad beta betad] for the next start.
            obj.P.x0 = s0(:); obj.pushParams();
        end
    end

    %% ================== Time signals ==================
    methods
        function setRefSignal(obj, t, rxy)
            %SETREFSIGNAL  rxy = [rx ry] (N x 2) [m]. Activates type 'external' centred at 0.
            assignin('base', 'ref_ext', [t(:) rxy]);
            obj.setRef('external', [0 0]);
        end
        function setVoltageSignal(~, t, U)
            %SETVOLTAGESIGNAL  U = [Va Vb] (N x 2) [V].
            assignin('base', 'u_ext', [t(:) U]);
        end
        function setDisturbanceSignal(~, t, F)
            %SETDISTURBANCESIGNAL  F = [Fx Fy] (N x 2) [N].
            assignin('base', 'd_ext', [t(:) F]);
        end
        function clearSignals(~)
            for v = {'u_ext', 'ref_ext', 'd_ext'}
                assignin('base', v{1}, [0 0 0; 1 0 0]);
            end
        end
    end

    %% ================== Execution ==================
    methods
        function res = run(obj, T)
            %RUN  Batch simulation of T seconds. Returns a results struct.
            if obj.isRunning(), error('A live simulation is running. Call stop() first.'); end
            obj.pushParams(); obj.applyCmd();
            set_param(obj.Model, 'StopTime', num2str(T), 'FixedStep', num2str(obj.P.h));
            obj.setPacing(false);
            obj.batch = true;
            c = onCleanup(@() obj.setBatch(false));
            out = sim(obj.Model);
            res = BallPlate.parse(out.tel, obj.P);
        end

        function start(obj)
            %START  Starts live (real time, StopTime = inf).
            if obj.isRunning(), return; end
            obj.pushParams(); obj.applyCmd();
            obj.LastTime = 0; obj.Last = zeros(23,1);
            set_param(obj.Model, 'StopTime', 'inf', 'FixedStep', num2str(obj.P.h));
            obj.setPacing(true);
            obj.batch = false;
            set_param(obj.Model, 'SimulationCommand', 'start');
        end

        function stop(obj)
            %STOP  Stops the live simulation and waits for it to finish.
            if obj.isRunning()
                set_param(obj.Model, 'SimulationCommand', 'stop');
                t0 = tic;
                while obj.isRunning() && toc(t0) < 5
                    pause(0.05);
                end
            end
        end
        function pause(obj)
            set_param(obj.Model, 'SimulationCommand', 'pause');
        end
        function resume(obj)
            set_param(obj.Model, 'SimulationCommand', 'continue');
        end

        function tf = isRunning(obj)
            st = get_param(obj.Model, 'SimulationStatus');
            tf = any(strcmp(st, {'running', 'paused', 'initializing', 'updating'}));
        end

        function res = lastResult(obj)
            %LASTRESULT  Results of the last live run (after stop).
            out = evalin('base', 'out');
            res = BallPlate.parse(out.tel, obj.P);
        end

        function animate(obj, res, speed)
            if nargin < 3, speed = 1; end
            bp_animate(res, obj.P, speed);
        end

        function addTelemetryCallback(obj, fcn)
            obj.telCallbacks{end+1} = fcn;
        end
        function addStopCallback(obj, fcn)
            obj.stopCallbacks{end+1} = fcn;
        end
        function clearCallbacks(obj)
            obj.telCallbacks = {}; obj.stopCallbacks = {};
        end

        function openModel(obj)
            open_system(obj.Model);
        end
    end

    %% ================== Internals ==================
    methods (Access = private)
        function pushParams(obj)
            assignin('base', 'P', obj.P);
        end

        function refresh(obj)
            if obj.isRunning()
                set_param(obj.Model, 'SimulationCommand', 'update');
            end
        end

        function applyCmd(obj)
            if ~bdIsLoaded(obj.Model), return; end
            set_param([obj.Model '/cmd_ctrl'], 'Value', mat2str(obj.CmdCtrl, 6));
            set_param([obj.Model '/cmd_ref'],  'Value', mat2str(obj.CmdRef, 6));
        end

        function clearPush(obj)
            try, set_param([obj.Model '/cmd_dist'], 'Value', '[0 0]'); catch, end
        end

        function setPacing(obj, on)
            try
                if on
                    set_param(obj.Model, 'EnablePacing', 'on', ...
                        'PacingRate', num2str(obj.PacingRate));
                else
                    set_param(obj.Model, 'EnablePacing', 'off');
                end
            catch
                if on, warning('This Simulink version does not support pacing; it will run faster than real time.'); end
            end
        end

        function setBatch(obj, v)
            obj.batch = v;
        end

        function attach(obj)
            obj.listener = add_exec_event_listener([obj.Model '/telemetry'], ...
                'PostOutputs', @(blk, ev) obj.onTel(blk));
            obj.tick = tic;
        end

        function onTel(obj, blk)
            obj.Last = blk.OutputPort(1).Data;
            obj.LastTime = blk.CurrentTime;
            if obj.batch || isempty(obj.telCallbacks), return; end
            if toc(obj.tick) >= obj.cbPeriod
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
            end
        end

        function detach(obj)
            if ~isempty(obj.listener), delete(obj.listener); obj.listener = []; end
            for k = 1:numel(obj.stopCallbacks)
                try, obj.stopCallbacks{k}(); catch, end
            end
        end
    end

    methods (Static)
        function onModelStart(mdl)
            obj = BallPlate.instance(mdl);
            if ~isempty(obj), obj.attach(); end
        end
        function onModelStop(mdl)
            obj = BallPlate.instance(mdl);
            if ~isempty(obj), obj.detach(); end
        end
        function obj = instance(mdl)
            obj = getappdata(0, 'BallPlateInstance');
            if isempty(obj) || ~isvalid(obj) || ~strcmp(obj.Model, mdl)
                obj = [];
            end
        end

        function res = parse(tel, P)
            %PARSE  Converts the telemetry (To Workspace) into a readable struct.
            d = tel.signals.values;
            if ndims(d) == 3, d = squeeze(d)'; end
            I = BallPlate.TEL;
            res.t = tel.time(:);
            f = fieldnames(I);
            for k = 1:numel(f)
                res.(f{k}) = d(:, I.(f{k}));
            end
            res.x_cm   = 100*res.x;   res.y_cm  = 100*res.y;
            res.rx_cm  = 100*res.rx;  res.ry_cm = 100*res.ry;
            res.al_deg = rad2deg(res.al);
            res.be_deg = rad2deg(res.be);
            res.P = P;
        end
    end
end
