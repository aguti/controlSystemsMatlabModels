function bb = bb_gui(bb)
%BB_GUI  Live visual interface of the ball and beam.
%
%   bb_gui              creates a new BallBeam and opens the panel
%   bb = bb_gui(bb)     uses an existing BallBeam object (you can keep
%                       sending it commands from the command line
%                       while the GUI is open)
%
%   The GUI shows positions in cm and angles in degrees; the code
%   interface uses metres and radians.
%   Keyboard (window focused): left/right arrows = tap the ball towards -x/+x;
%   up/down arrows = beam angle +-1 deg (mode "Beam").
%   The 3D view can be rotated with the mouse or set from the "View" list.

if nargin < 1 || isempty(bb), bb = BallBeam(); end
P = bb.P;
Twin = 10;                                    % plot time window [s]
xMaxCm = 100*P.x_max;

%% ---------------- Window and layout ----------------
fig = uifigure('Name', 'Ball and beam — live Simulink', ...
    'Position', [60 60 1300 800]);
G = uigridlayout(fig, [1 2]);
G.ColumnWidth = {'1x', 340};

L = uigridlayout(G, [4 1]);
L.RowHeight = {'3x', '1x', '1x', '1x'};
axA = uiaxes(L); title(axA, 'Ball and beam');
axX = uiaxes(L); ylabel(axX, 'x [cm]'); grid(axX, 'on');
axB = uiaxes(L); ylabel(axB, '\alpha [deg]'); grid(axB, 'on');
axV = uiaxes(L); ylabel(axV, 'V [V]'); xlabel(axV, 't [s]'); grid(axV, 'on');

R = uigridlayout(G, [7 1]);
R.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
R.Scrollable = 'on';

%% ---------------- Simulation ----------------
p1 = uipanel(R, 'Title', 'Simulation');
g1 = uigridlayout(p1, [4 3]); g1.RowHeight = repmat({'fit'}, 1, 4);
bStart = uibutton(g1, 'Text', '▶ Start', 'ButtonPushedFcn', @onStart, ...
    'BackgroundColor', [0.75 0.9 0.75]);
bPause = uibutton(g1, 'Text', '❚❚ Pause', 'ButtonPushedFcn', @onPause, 'Enable', 'off');
bStop  = uibutton(g1, 'Text', '■ Stop', 'ButtonPushedFcn', @onStop, 'Enable', 'off', ...
    'BackgroundColor', [0.95 0.75 0.75]);
uilabel(g1, 'Text', 'x0 [cm], α0 [°]');
efX0  = uieditfield(g1, 'numeric', 'Value', 100*P.x0(1), 'Limits', [-xMaxCm xMaxCm]);
efAl0 = uieditfield(g1, 'numeric', 'Value', rad2deg(P.x0(3)), 'Limits', rad2deg(P.al_max)*[-1 1]);
uilabel(g1, 'Text', 'Speed');
ddRate = uidropdown(g1, 'Items', {'0.25x', '0.5x', '1x', '2x'}, 'Value', '1x');
ddRate.Layout.Column = [2 3];
uilabel(g1, 'Text', 'View');
ddView = uidropdown(g1, 'Items', {'3D', 'Front', 'Top', 'Side'}, 'ItemsData', {'iso', 'front', 'top', 'side'}, ...
    'Value', 'iso', 'ValueChangedFcn', @(s,~) bb_view(axA, s.Value));
ddView.Layout.Column = [2 3];

%% ---------------- Control ----------------
p2 = uipanel(R, 'Title', 'Control');
g2 = uigridlayout(p2, [6 2]); g2.RowHeight = repmat({'fit'}, 1, 6);
g2.ColumnWidth = {110, '1x'};
uilabel(g2, 'Text', 'Mode');
modeItems = {'0  Open loop (manual V)', '1  Beam angle servo', ...
             '2  Cascade PID + PD', '3  LQR + integral'};
ddMode = uidropdown(g2, 'Items', modeItems, 'ItemsData', 0:3, ...
    'Value', bb.CmdCtrl(1), 'ValueChangedFcn', @(s,~) bb.setMode(s.Value));
cbEn = uicheckbox(g2, 'Text', 'Control enabled', 'Value', bb.CmdCtrl(2) > 0, ...
    'ValueChangedFcn', @(s,~) bb.enable(s.Value));
cbFF = uicheckbox(g2, 'Text', 'Weight feedforward', 'Value', P.ff_on > 0, ...
    'ValueChangedFcn', @(s,~) bb.setParam('ff_on', double(s.Value)));
lblU = uilabel(g2, 'Text', 'Manual V: 0.0 V');
slU = uislider(g2, 'Limits', [-P.Vmax P.Vmax], 'Value', 0, ...
    'ValueChangingFcn', @(~,e) setManual(e.Value), ...
    'ValueChangedFcn',  @(s,~) setManual(s.Value));
lblA = uilabel(g2, 'Text', 'Beam α: 0.0°');
alMaxDeg = floor(rad2deg(P.al_max));
slA = uislider(g2, 'Limits', [-alMaxDeg alMaxDeg], 'Value', 0, ...
    'ValueChangingFcn', @(~,e) setBeam(e.Value), ...
    'ValueChangedFcn',  @(s,~) setBeam(s.Value), 'MajorTicks', -20:10:20);
uibutton(g2, 'Text', '◀ Tap', 'ButtonPushedFcn', @(~,~) doPush(-1));
uibutton(g2, 'Text', 'Tap ▶', 'ButtonPushedFcn', @(~,~) doPush(+1));
uilabel(g2, 'Text', 'Tap force [N]');
efPush = uieditfield(g2, 'numeric', 'Value', 0.2, 'Limits', [0 2]);

%% ---------------- Reference ----------------
p3 = uipanel(R, 'Title', 'Ball reference');
g3 = uigridlayout(p3, [4 2]); g3.RowHeight = repmat({'fit'}, 1, 4);
g3.ColumnWidth = {110, '1x'};
uilabel(g3, 'Text', 'Type');
ddRef = uidropdown(g3, 'Items', {'Constant', 'Sine', 'Square', 'Triangle', 'External (ref_ext)'}, ...
    'ItemsData', 0:4, 'Value', 0, 'ValueChangedFcn', @(~,~) sendRef());
lblOff = uilabel(g3, 'Text', 'Offset: 0 cm');
refMaxCm = 100*P.x_ref_max;
slOff = uislider(g3, 'Limits', [-refMaxCm refMaxCm], 'Value', 0, ...
    'ValueChangingFcn', @(~,e) sendRef(e.Value), 'ValueChangedFcn', @(~,~) sendRef());
uilabel(g3, 'Text', 'Amplitude [cm]');
efAmp = uieditfield(g3, 'numeric', 'Value', 10, 'Limits', [0 refMaxCm], ...
    'ValueChangedFcn', @(~,~) sendRef());
uilabel(g3, 'Text', 'Frequency [Hz]');
efFreq = uieditfield(g3, 'numeric', 'Value', 0.1, 'Limits', [0 5], ...
    'ValueChangedFcn', @(~,~) sendRef());

%% ---------------- Tuning ----------------
p4 = uipanel(R, 'Title', 'Tuning (applied live)');
g4 = uigridlayout(p4, [7 4]); g4.RowHeight = repmat({'fit'}, 1, 7);
lC = uilabel(g4, 'Text', 'Cascade (ball PID)', 'FontWeight', 'bold'); lC.Layout.Column = [1 4];
uilabel(g4, 'Text', 'Kp'); efKp = uieditfield(g4, 'numeric', 'Value', P.Kp_x, 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Kd'); efKd = uieditfield(g4, 'numeric', 'Value', P.Kd_x, 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Ki'); efKi = uieditfield(g4, 'numeric', 'Value', P.Ki_x, 'Limits', [0 Inf]);
lQ = uilabel(g4, 'Text', 'LQR weights', 'FontWeight', 'bold'); lQ.Layout.Column = [3 4];
uilabel(g4, 'Text', 'Qx');  efQx = uieditfield(g4, 'numeric', 'Value', P.Q(1,1), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qα');  efQa = uieditfield(g4, 'numeric', 'Value', P.Q(3,3), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qint'); efQi = uieditfield(g4, 'numeric', 'Value', P.Q(5,5), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'R');   efR  = uieditfield(g4, 'numeric', 'Value', P.R, 'Limits', [1e-6 Inf]);
bK = uibutton(g4, 'Text', 'Apply gains / recompute K', 'ButtonPushedFcn', @(~,~) redesign());
bK.Layout.Column = [1 4];
lblK = uilabel(g4, 'Text', kText(bb.P.K), 'FontName', 'Consolas');
lblK.Layout.Column = [1 4];

%% ---------------- Sensors / data ----------------
p5 = uipanel(R, 'Title', 'Sensors and data');
g5 = uigridlayout(p5, [2 2]); g5.RowHeight = {'fit', 'fit'};
uicheckbox(g5, 'Text', 'Sensor noise', 'Value', P.noise_on > 0, ...
    'ValueChangedFcn', @(s,~) bb.setParam('noise_on', double(s.Value)));
uibutton(g5, 'Text', 'Open model', 'ButtonPushedFcn', @(~,~) bb.openModel());
bExp = uibutton(g5, 'Text', 'Export last run → bb_res', 'ButtonPushedFcn', @(~,~) exportRes());
bExp.Layout.Column = [1 2];

%% ---------------- Status ----------------
p6 = uipanel(R, 'Title', 'Status');
g6 = uigridlayout(p6, [1 1]);
lblS = uilabel(g6, 'Text', 'Stopped', 'FontName', 'Consolas', 'WordWrap', 'on');

%% ---------------- Live plots ----------------
hA = bb_draw(axA, P);
bb_draw(axA, P, hA, P.x0(1), P.x0(3), 0);
axA.XTickLabel = {}; axA.YTickLabel = {}; axA.ZTickLabel = {};
xlabel(axA, ''); ylabel(axA, ''); zlabel(axA, '');
nPts = Twin*bb.TelemetryRate*3;
lx  = animatedline(axX, 'Color', [0.85 0.33 0.10], 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lr  = animatedline(axX, 'Color', [0.47 0.67 0.19], 'LineStyle', '--', 'MaximumNumPoints', nPts);
lal = animatedline(axB, 'Color', [0.00 0.45 0.74], 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lar = animatedline(axB, 'Color', [0.30 0.75 0.93], 'LineStyle', '--', 'MaximumNumPoints', nPts);
lV  = animatedline(axV, 'Color', [0.49 0.18 0.56], 'MaximumNumPoints', nPts);
legend(axX, {'x', 'r'}, 'Location', 'northwest');
legend(axB, {'\alpha', '\alpha_{ref}'}, 'Location', 'northwest');
try, set([axX axB axV], 'YLimitMethod', 'padded'); catch, end   % R2021a+

I = BallBeam.TEL;
bb.clearCallbacks();
bb.addTelemetryCallback(@onTelemetry);
bb.addStopCallback(@onSimStopped);

fig.WindowKeyPressFcn = @onKey;
fig.CloseRequestFcn   = @onClose;
efX0.ValueChangedFcn  = @(~,~) previewIC();
efAl0.ValueChangedFcn = @(~,~) previewIC();

%% ======================= callbacks =======================
    function previewIC()
        if bb.isRunning(), return; end
        bb_draw(axA, P, hA, efX0.Value/100, deg2rad(efAl0.Value), slOff.Value/100);
    end

    function onStart(~, ~)
        bb.setInitialState([efX0.Value/100 0 deg2rad(efAl0.Value) 0]);
        bb.PacingRate = str2double(erase(ddRate.Value, 'x'));
        clearpoints(lx); clearpoints(lr); clearpoints(lal); clearpoints(lar); clearpoints(lV);
        sendRef(); bb.setMode(ddMode.Value); bb.enable(cbEn.Value);
        bb.start();
        bStart.Enable = 'off'; bStop.Enable = 'on'; bPause.Enable = 'on';
        efX0.Enable = 'off'; efAl0.Enable = 'off'; ddRate.Enable = 'off';
    end

    function onPause(~, ~)
        if strcmp(get_param(bb.Model, 'SimulationStatus'), 'paused')
            bb.resume(); bPause.Text = '❚❚ Pause';
        else
            bb.pause(); bPause.Text = '▶ Resume';
        end
    end

    function onStop(~, ~)
        bb.stop();
    end

    function onSimStopped()
        if ~isvalid(fig), return; end
        bStart.Enable = 'on'; bStop.Enable = 'off'; bPause.Enable = 'off';
        bPause.Text = '❚❚ Pause';
        efX0.Enable = 'on'; efAl0.Enable = 'on'; ddRate.Enable = 'on';
        lblS.Text = sprintf('Stopped at t = %.2f s', bb.LastTime);
    end

    function onTelemetry(t, d)
        if ~isvalid(fig), return; end
        bb_draw(axA, P, hA, d(I.x), d(I.al), d(I.r));
        addpoints(lx, t, 100*d(I.x)); addpoints(lr, t, 100*d(I.r));
        addpoints(lal, t, rad2deg(d(I.al)));
        if any(d(I.mode) == [1 2]), addpoints(lar, t, rad2deg(d(I.alr))); end
        addpoints(lV, t, d(I.Vact));
        xl = [max(0, t - Twin), max(Twin, t)];
        xlim(axX, xl); xlim(axB, xl); xlim(axV, xl);
        st = '';
        if abs(d(I.x)) >= P.x_max - 1e-3, st = '  ⚠ ball at the end stop'; end
        lblS.Text = sprintf('t = %6.2f s   mode %d\nx = %+6.1f cm   r = %+6.1f cm\nα = %+5.1f°   V = %+5.1f V%s', ...
            t, d(I.mode), 100*d(I.x), 100*d(I.r), rad2deg(d(I.al)), d(I.Vact), st);
        axA.Title.String = sprintf('t = %.1f s', t);
        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost
    end

    function setManual(u)
        lblU.Text = sprintf('Manual V: %+.1f V', u);
        bb.setVoltage(u);
    end

    function setBeam(aDeg)
        aDeg = max(min(aDeg, alMaxDeg), -alMaxDeg);
        slA.Value = aDeg;
        lblA.Text = sprintf('Beam α: %+.1f°', aDeg);
        bb.setBeamAngle(deg2rad(aDeg));
    end

    function doPush(sgn)
        if bb.isRunning(), bb.push(sgn*efPush.Value, 0.05); end
    end

    function sendRef(offOverride)
        off = slOff.Value;
        if nargin > 0, off = offOverride; end
        lblOff.Text = sprintf('Offset: %+.1f cm', off);
        bb.setRef(ddRef.Value, off/100, efAmp.Value/100, efFreq.Value);
        if ~bb.isRunning()
            bb_draw(axA, P, hA, efX0.Value/100, deg2rad(efAl0.Value), off/100);
        end
    end

    function redesign()
        Q = bb.P.Q; Q(1,1) = efQx.Value; Q(3,3) = efQa.Value; Q(5,5) = efQi.Value;
        bb.setParams(struct('Q', Q, 'R', efR.Value, ...
            'Kp_x', efKp.Value, 'Kd_x', efKd.Value, 'Ki_x', efKi.Value));
        lblK.Text = kText(bb.P.K);
    end

    function exportRes()
        try
            res = bb.lastResult();
            assignin('base', 'bb_res', res);
            bb_plot_results(res, 'Last live run');
        catch err
            uialert(fig, ['No data yet: ' err.message], 'Export');
        end
    end

    function onKey(~, e)
        switch e.Key
            case 'leftarrow',  doPush(-1);
            case 'rightarrow', doPush(+1);
            case 'uparrow',    setBeam(slA.Value + 1);
            case 'downarrow',  setBeam(slA.Value - 1);
        end
    end

    function onClose(~, ~)
        try, bb.stop(); catch, end
        bb.clearCallbacks();
        delete(fig);
    end
end

function s = kText(K)
s = sprintf('K = [%.1f %.1f %.1f %.2f %.1f]', K);
end
