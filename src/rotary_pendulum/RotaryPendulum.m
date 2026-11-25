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
        TelemetryRate = 30      % maximum rate [Hz] at which live callbacks are called
        GuiLoad = 0.4           % maximum fraction of wall time spent in live callbacks
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
        cbPeriod = 0
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
            obj.P = rp_params();
            [obj.P, obj.Lin] = rp_design(obj.P);
            obj.pushParams();
            for v = {'u_ext', 'ref_ext', 'd_ext'}
                assignin('base', v{1}, [0 0; 1 0]);
            end
            if ~bdIsLoaded(obj.Model)
                if exist(fullfile(here, [obj.Model '.slx']), 'file')
                    load_system(fullfile(here, [obj.Model '.slx']));
                else
                    rp_build_model(obj.Model);
                end
            end
            obj.tick = tic;
            setappdata(0, 'RotaryPendulumInstance', obj);
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
            %SETMODE  0/'open' 1/'lqr' 2/'swingup' 3/'pid' 4/'down'
            if ischar(m) || isstring(m)
                m = find(strcmpi(obj.MODES, m)) - 1;
                assert(~isempty(m), 'Unknown mode');
            end
            obj.CmdCtrl(1) = m; obj.applyCmd();
        end

        function enable(obj, tf)
            obj.CmdCtrl(2) = double(logical(tf)); obj.applyCmd();
        end

        function setVoltage(obj, u)
            %SETVOLTAGE  Manual voltage [V] added to the controller's.
            obj.CmdCtrl(3) = max(min(u, obj.P.Vmax), -obj.P.Vmax); obj.applyCmd();
        end

        function setRef(obj, type, offset, amp, freq)
            %SETREF  setRef(type, offset, amplitude, frequency)   (angles in rad)
            %   type: 'const' | 'sine' | 'square' | 'triangle' | 'external' (or 0..4)
            if ischar(type) || isstring(type)
                type = find(strcmpi(obj.REFTYPES, type)) - 1;
                assert(~isempty(type), 'Unknown reference type');
            end
            if nargin < 3, offset = obj.CmdRef(2); end
            if nargin < 4, amp = obj.CmdRef(3); end
            if nargin < 5, freq = obj.CmdRef(4); end
            obj.CmdRef = [type offset amp freq]; obj.applyCmd();
        end

        function push(obj, F, dur)
            %PUSH  Tangential push at the pendulum tip (live). F [N], dur [s].
            if nargin < 2, F = 0.05; end
            if nargin < 3, dur = 0.05; end
            set_param([obj.Model '/cmd_dist'], 'Value', num2str(F));
            if ~isempty(obj.pushTimer) && isvalid(obj.pushTimer)
                stop(obj.pushTimer); delete(obj.pushTimer);
            end
            obj.pushTimer = timer('StartDelay', round(dur/obj.PacingRate*1000)/1000, ...
                'ExecutionMode', 'singleShot', 'TimerFcn', @(~,~) obj.clearPush());
            start(obj.pushTimer);
        end

        function setParam(obj, name, value)
            %SETPARAM  Changes a parameter; recomputes the LQR and updates live.
            assert(isfield(obj.P, name), 'Unknown parameter: %s', name);
            obj.P.(name) = value;
            [obj.P, obj.Lin] = rp_design(obj.P);
            obj.pushParams();
            obj.refresh();
        end

        function setParamRaw(obj, name, value)
            %SETPARAMRAW  Changes a parameter WITHOUT recomputing the gains.
            %   Useful for robustness tests (true plant ~= nominal) or to
            %   impose gains by hand: rp.setParamRaw('K_up', [...]).
            assert(isfield(obj.P, name), 'Unknown parameter: %s', name);
            obj.P.(name) = value;
            obj.pushParams();
            obj.refresh();
        end

        function setParams(obj, S)
            %SETPARAMS  Several at once: rp.setParams(struct('mp',0.03,'Lp',0.15))
            f = fieldnames(S);
            for k = 1:numel(f)
                assert(isfield(obj.P, f{k}), 'Unknown parameter: %s', f{k});
                obj.P.(f{k}) = S.(f{k});
            end
            [obj.P, obj.Lin] = rp_design(obj.P);
            obj.pushParams(); obj.refresh();
        end

        function setInitialState(obj, s0)
            %SETINITIALSTATE  [theta thetad alpha alphad] for the next start.
            obj.P.x0 = s0(:); obj.pushParams();
        end
    end

    %% ================== Time signals ==================
    methods
        function setRefSignal(obj, t, r)
            assignin('base', 'ref_ext', [t(:) r(:)]);
            obj.setRef('external', 0);
        end
        function setVoltageSignal(~, t, u)
            assignin('base', 'u_ext', [t(:) u(:)]);
        end
        function setDisturbanceSignal(~, t, Fd)
            assignin('base', 'd_ext', [t(:) Fd(:)]);
        end
        function clearSignals(~)
            for v = {'u_ext', 'ref_ext', 'd_ext'}
                assignin('base', v{1}, [0 0; 1 0]);
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
            res = RotaryPendulum.parse(out.tel, obj.P);
        end

        function start(obj)
            %START  Starts live (real time, StopTime = inf).
            if obj.isRunning(), return; end
            obj.pushParams(); obj.applyCmd();
            obj.LastTime = 0; obj.Last = zeros(13,1);
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
            res = RotaryPendulum.parse(out.tel, obj.P);
        end

        function animate(obj, res, speed)
            if nargin < 3, speed = 1; end
            rp_animate(res, obj.P, speed);
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
            try, set_param([obj.Model '/cmd_dist'], 'Value', '0'); catch, end
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
            obj = RotaryPendulum.instance(mdl);
            if ~isempty(obj), obj.attach(); end
        end
        function onModelStop(mdl)
            obj = RotaryPendulum.instance(mdl);
            if ~isempty(obj), obj.detach(); end
        end
        function obj = instance(mdl)
            obj = getappdata(0, 'RotaryPendulumInstance');
            if isempty(obj) || ~isvalid(obj) || ~strcmp(obj.Model, mdl)
                obj = [];
            end
        end

        function res = parse(tel, P)
            %PARSE  Converts the telemetry (To Workspace) into a readable struct.
            d = tel.signals.values;
            if ndims(d) == 3, d = squeeze(d)'; end
            I = RotaryPendulum.TEL;
            res.t = tel.time(:);
            f = fieldnames(I);
            for k = 1:numel(f)
                res.(f{k}) = d(:, I.(f{k}));
            end
            res.th_deg = rad2deg(res.th);                       % arm: not wrapped
            res.al_deg = rad2deg(mod(res.al + pi, 2*pi) - pi);  % pendulum: wrapped
            res.r_deg  = rad2deg(res.r);
            res.P = P;
        end
    end
end
