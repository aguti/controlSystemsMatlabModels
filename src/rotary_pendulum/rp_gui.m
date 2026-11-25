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
             '3  PID pendulum + PD arm', '4  Down (anti-sway)'};
ddMode = uidropdown(g2, 'Items', modeItems, 'ItemsData', 0:4, ...
    'Value', rp.CmdCtrl(1), 'ValueChangedFcn', @(s,~) rp.setMode(s.Value));
cbEn = uicheckbox(g2, 'Text', 'Control enabled', 'Value', rp.CmdCtrl(2) > 0, ...
    'ValueChangedFcn', @(s,~) rp.enable(s.Value));
cbEn.Layout.Column = [1 2];
lblU = uilabel(g2, 'Text', 'Manual V: 0.0 V');
slU = uislider(g2, 'Limits', [-P.Vmax P.Vmax], 'Value', 0, ...
    'ValueChangingFcn', @(~,e) setManual(e.Value), ...
    'ValueChangedFcn',  @(s,~) setManual(s.Value));
uibutton(g2, 'Text', 'Manual V = 0', 'ButtonPushedFcn', @(~,~) setManual(0, true));
uibutton(g2, 'Text', 'Push ➜', 'ButtonPushedFcn', @(~,~) doPush());
uilabel(g2, 'Text', 'Push [N]');
efPush = uieditfield(g2, 'numeric', 'Value', 0.05, 'Limits', [-1 1]);

%% ---------------- Reference ----------------
p3 = uipanel(R, 'Title', 'Arm reference');
g3 = uigridlayout(p3, [4 2]); g3.RowHeight = repmat({'fit'}, 1, 4);
g3.ColumnWidth = {110, '1x'};
uilabel(g3, 'Text', 'Type');
ddRef = uidropdown(g3, 'Items', {'Constant', 'Sine', 'Square', 'Triangle', 'External (ref_ext)'}, ...
    'ItemsData', 0:4, 'Value', 0, 'ValueChangedFcn', @(~,~) sendRef());
lblOff = uilabel(g3, 'Text', 'Offset: 0 deg');
refMaxDeg = rad2deg(P.th_ref_max);
slOff = uislider(g3, 'Limits', [-refMaxDeg refMaxDeg], 'Value', 0, ...
    'ValueChangingFcn', @(~,e) sendRef(e.Value), 'ValueChangedFcn', @(~,~) sendRef());
uilabel(g3, 'Text', 'Amplitude [deg]');
efAmp = uieditfield(g3, 'numeric', 'Value', 45, 'Limits', [0 refMaxDeg], ...
    'ValueChangedFcn', @(~,~) sendRef());
uilabel(g3, 'Text', 'Frequency [Hz]');
efFreq = uieditfield(g3, 'numeric', 'Value', 0.2, 'Limits', [0 5], ...
    'ValueChangedFcn', @(~,~) sendRef());

%% ---------------- LQR tuning ----------------
p4 = uipanel(R, 'Title', 'LQR tuning (up)');
g4 = uigridlayout(p4, [4 4]); g4.RowHeight = repmat({'fit'}, 1, 4);
uilabel(g4, 'Text', 'Qθ'); efQt = uieditfield(g4, 'numeric', 'Value', P.Qup(1,1), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qα'); efQa = uieditfield(g4, 'numeric', 'Value', P.Qup(3,3), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qθ̇'); efQv = uieditfield(g4, 'numeric', 'Value', P.Qup(2,2), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'R');  efR  = uieditfield(g4, 'numeric', 'Value', P.Rup, 'Limits', [1e-6 Inf]);
bK = uibutton(g4, 'Text', 'Recompute K (live)', 'ButtonPushedFcn', @(~,~) redesign());
bK.Layout.Column = [1 4];
lblK = uilabel(g4, 'Text', kText(rp.P.K_up), 'FontName', 'Consolas');
lblK.Layout.Column = [1 4];

%% ---------------- Sensors / data ----------------
p5 = uipanel(R, 'Title', 'Sensors and data');
g5 = uigridlayout(p5, [2 2]); g5.RowHeight = {'fit', 'fit'};
uicheckbox(g5, 'Text', 'Encoder noise', 'Value', P.noise_on > 0, ...
    'ValueChangedFcn', @(s,~) rp.setParam('noise_on', double(s.Value)));
uibutton(g5, 'Text', 'Open model', 'ButtonPushedFcn', @(~,~) rp.openModel());
bExp = uibutton(g5, 'Text', 'Export last run → rp_res', 'ButtonPushedFcn', @(~,~) exportRes());
bExp.Layout.Column = [1 2];

%% ---------------- Status ----------------
p6 = uipanel(R, 'Title', 'Status');
g6 = uigridlayout(p6, [1 1]);
lblS = uilabel(g6, 'Text', 'Stopped', 'FontName', 'Consolas', 'WordWrap', 'on');

%% ---------------- Live plots ----------------
hA = rp_draw(axA, P);
rp_draw(axA, P, hA, P.x0(1), P.x0(3), 0);
axA.XTickLabel = {}; axA.YTickLabel = {}; axA.ZTickLabel = {};   % more room for the scene
xlabel(axA, ''); ylabel(axA, ''); zlabel(axA, '');
nPts = Twin*rp.TelemetryRate*3;
lth = animatedline(axT, 'Color', [0.00 0.45 0.74], 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lr  = animatedline(axT, 'Color', [0.47 0.67 0.19], 'LineStyle', '--', 'MaximumNumPoints', nPts);
lal = animatedline(axP, 'Color', [0.85 0.33 0.10], 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lV  = animatedline(axV, 'Color', [0.49 0.18 0.56], 'MaximumNumPoints', nPts);
legend(axT, {'\theta', 'r'}, 'Location', 'northwest');
try, set([axT axP axV], 'YLimitMethod', 'padded'); catch, end   % R2021a+

I = RotaryPendulum.TEL;
rp.clearCallbacks();
rp.addTelemetryCallback(@onTelemetry);
rp.addStopCallback(@onSimStopped);

fig.WindowKeyPressFcn   = @onKey;
fig.WindowKeyReleaseFcn = @onKeyUp;
fig.CloseRequestFcn     = @onClose;
uManual = 0; keyDown = false;
ddIC.ValueChangedFcn = @(~,~) previewIC();
efAl0.ValueChangedFcn = @(~,~) previewIC();
efTh0.ValueChangedFcn = @(~,~) previewIC();

%% ======================= callbacks =======================
    function [th0, al0] = initialState()
        th0 = deg2rad(efTh0.Value);
        al0 = deg2rad(efAl0.Value);
        if startsWith(ddIC.Value, 'Down'), al0 = pi; end
    end

    function previewIC()
        if rp.isRunning(), return; end
        [th0, al0] = initialState();
        rp_draw(axA, P, hA, th0, al0, deg2rad(slOff.Value));
    end

    function onStart(~, ~)
        [th0, al0] = initialState();
        rp.setInitialState([th0 0 al0 0]);
        rp.PacingRate = str2double(erase(ddRate.Value, 'x'));
        clearpoints(lth); clearpoints(lr); clearpoints(lal); clearpoints(lV);
        sendRef(); rp.setMode(ddMode.Value); rp.enable(cbEn.Value);
        rp.start();
        bStart.Enable = 'off'; bStop.Enable = 'on'; bPause.Enable = 'on';
        ddIC.Enable = 'off'; efAl0.Enable = 'off'; efTh0.Enable = 'off'; ddRate.Enable = 'off';
    end

    function onPause(~, ~)
        if strcmp(get_param(rp.Model, 'SimulationStatus'), 'paused')
            rp.resume(); bPause.Text = '❚❚ Pause';
        else
            rp.pause(); bPause.Text = '▶ Resume';
        end
    end

    function onStop(~, ~)
        rp.stop();
    end

    function onSimStopped()
        if ~isvalid(fig), return; end
        bStart.Enable = 'on'; bStop.Enable = 'off'; bPause.Enable = 'off';
        bPause.Text = '❚❚ Pause';
        ddIC.Enable = 'on'; efAl0.Enable = 'on'; efTh0.Enable = 'on'; ddRate.Enable = 'on';
        lblS.Text = sprintf('Stopped at t = %.2f s', rp.LastTime);
    end

    function onTelemetry(t, d)
        if ~isvalid(fig), return; end
        rp_draw(axA, P, hA, d(I.th), d(I.al), d(I.r));
        thDeg = rad2deg(d(I.th));
        alDeg = rad2deg(mod(d(I.al) + pi, 2*pi) - pi);
        addpoints(lth, t, thDeg); addpoints(lr, t, rad2deg(d(I.r)));
        addpoints(lal, t, alDeg); addpoints(lV, t, d(I.Vact));
        xl = [max(0, t - Twin), max(Twin, t)];
        xlim(axT, xl); xlim(axP, xl); xlim(axV, xl);
        st = '';
        if d(I.tripped) > 0.5, st = '  ⚠ SAFETY: control cut off (untick/tick "enabled")'; end
        if d(I.mode) == 2
            if d(I.caught) > 0.5, st = [st '  [LQR caught]']; else, st = sprintf('%s  [swing-up, E = %.1f mJ]', st, 1e3*d(I.E)); end
        end
        lblS.Text = sprintf('t = %6.2f s   mode %d\nθ = %+7.1f°   α = %+6.1f°\nV = %+5.1f V   r = %+6.1f°%s', ...
            t, d(I.mode), thDeg, alDeg, d(I.Vact), rad2deg(d(I.r)), st);
        axA.Title.String = sprintf('t = %.1f s', t);
        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost
    end

    function setManual(u, updateSlider)
        uManual = u;
        if nargin > 1 && updateSlider, slU.Value = u; end
        lblU.Text = sprintf('Manual V: %+.1f V', u);
        if ~keyDown, rp.setVoltage(u); end
    end

    function doPush()
        if rp.isRunning(), rp.push(efPush.Value, 0.05); end
    end

    function sendRef(offOverride)
        off = slOff.Value;
        if nargin > 0, off = offOverride; end
        lblOff.Text = sprintf('Offset: %+.0f deg', off);
        rp.setRef(ddRef.Value, deg2rad(off), deg2rad(efAmp.Value), efFreq.Value);
        if ~rp.isRunning()
            [th0, al0] = initialState();
            rp_draw(axA, P, hA, th0, al0, deg2rad(off));
        end
    end

    function redesign()
        Q = rp.P.Qup; Q(1,1) = efQt.Value; Q(2,2) = efQv.Value; Q(3,3) = efQa.Value;
        rp.setParams(struct('Qup', Q, 'Rup', efR.Value));
        lblK.Text = kText(rp.P.K_up);
    end

    function exportRes()
        try
            res = rp.lastResult();
            assignin('base', 'rp_res', res);
            rp_plot_results(res, 'Last live run');
        catch err
            uialert(fig, ['No data yet: ' err.message], 'Export');
        end
    end

    function onKey(~, e)
        switch e.Key
            case 'leftarrow',  keyDown = true; rp.setVoltage(uManual - KeyVoltage);
            case 'rightarrow', keyDown = true; rp.setVoltage(uManual + KeyVoltage);
            case 'space',      doPush();
        end
    end

    function onKeyUp(~, e)
        if any(strcmp(e.Key, {'leftarrow', 'rightarrow'}))
            keyDown = false; rp.setVoltage(uManual);
        end
    end

    function onClose(~, ~)
        try, rp.stop(); catch, end
        rp.clearCallbacks();
        delete(fig);
    end
end

function s = kText(K)
s = sprintf('K = [%.2f  %.2f  %.1f  %.2f]', K);
end
