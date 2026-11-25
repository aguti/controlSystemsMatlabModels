function cp = cp_gui(cp)
%CP_GUI  Live visual interface of the linear pendulum (cart-pole).
%
%   cp_gui              creates a new CartPole and opens the panel
%   cp = cp_gui(cp)     uses an existing CartPole object (you can keep
%                       sending it commands from the command line
%                       while the GUI is open)
%
%   Keyboard (window focused): left/right arrows = manual force of
%   ±KeyForce N while held down; space = push.

if nargin < 1 || isempty(cp), cp = CartPole(); end
P = cp.P;
KeyForce = 5;
Twin = 10;                                    % plot time window [s]

%% ---------------- Window and layout ----------------
fig = uifigure('Name', 'Linear pendulum — live Simulink', ...
    'Position', [60 60 1300 780]);
G = uigridlayout(fig, [1 2]);
G.ColumnWidth = {'1x', 340};

L = uigridlayout(G, [4 1]);
L.RowHeight = {'1.5x', '1x', '1x', '1x'};
axA = uiaxes(L); title(axA, 'Cart-pole');
axX = uiaxes(L); ylabel(axX, 'x [m]');  grid(axX, 'on');
axT = uiaxes(L); ylabel(axT, '\theta [deg]'); grid(axT, 'on');
axF = uiaxes(L); ylabel(axF, 'F [N]'); xlabel(axF, 't [s]'); grid(axF, 'on');

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
uilabel(g1, 'Text', 'Initial state');
ddIC = uidropdown(g1, 'Items', {'Up (θ0)', 'Down (θ=π)'}, 'Value', 'Up (θ0)');
ddIC.Layout.Column = [2 3];
uilabel(g1, 'Text', 'θ0 [deg] / x0 [m]');
efTh0 = uieditfield(g1, 'numeric', 'Value', rad2deg(P.x0(3)));
efX0  = uieditfield(g1, 'numeric', 'Value', P.x0(1), 'Limits', [-0.6 0.6]);
uilabel(g1, 'Text', 'Speed');
ddRate = uidropdown(g1, 'Items', {'0.25x', '0.5x', '1x', '2x'}, 'Value', '1x');
ddRate.Layout.Column = [2 3];

%% ---------------- Control ----------------
p2 = uipanel(R, 'Title', 'Control');
g2 = uigridlayout(p2, [5 2]); g2.RowHeight = repmat({'fit'}, 1, 5);
g2.ColumnWidth = {110, '1x'};
uilabel(g2, 'Text', 'Mode');
modeItems = {'0  Open loop (manual)', '1  LQR up', '2  Swing-up + LQR', ...
             '3  PID angle + PD cart', '4  Crane (down, anti-sway)'};
ddMode = uidropdown(g2, 'Items', modeItems, 'ItemsData', 0:4, ...
    'Value', cp.CmdCtrl(1), 'ValueChangedFcn', @(s,~) cp.setMode(s.Value));
cbEn = uicheckbox(g2, 'Text', 'Control enabled', 'Value', cp.CmdCtrl(2) > 0, ...
    'ValueChangedFcn', @(s,~) cp.enable(s.Value));
cbEn.Layout.Column = [1 2];
lblF = uilabel(g2, 'Text', 'Manual F: 0.0 N');
slF = uislider(g2, 'Limits', [-P.Fmax P.Fmax], 'Value', 0, ...
    'ValueChangingFcn', @(~,e) setManual(e.Value), ...
    'ValueChangedFcn',  @(s,~) setManual(s.Value));
bZero = uibutton(g2, 'Text', 'Manual F = 0', 'ButtonPushedFcn', @(~,~) setManual(0, true));
bPush = uibutton(g2, 'Text', 'Push ➜', 'ButtonPushedFcn', @(~,~) doPush());
uilabel(g2, 'Text', 'Push [N]');
efPush = uieditfield(g2, 'numeric', 'Value', 1, 'Limits', [-10 10]);

%% ---------------- Reference ----------------
p3 = uipanel(R, 'Title', 'Cart reference');
g3 = uigridlayout(p3, [4 2]); g3.RowHeight = repmat({'fit'}, 1, 4);
g3.ColumnWidth = {110, '1x'};
uilabel(g3, 'Text', 'Type');
ddRef = uidropdown(g3, 'Items', {'Constant', 'Sine', 'Square', 'Triangle', 'External (ref_ext)'}, ...
    'ItemsData', 0:4, 'Value', 0, 'ValueChangedFcn', @(~,~) sendRef());
lblOff = uilabel(g3, 'Text', 'Offset: 0.00 m');
slOff = uislider(g3, 'Limits', [-P.x_ref_max P.x_ref_max], 'Value', 0, ...
    'ValueChangingFcn', @(~,e) sendRef(e.Value), 'ValueChangedFcn', @(~,~) sendRef());
uilabel(g3, 'Text', 'Amplitude [m]');
efAmp = uieditfield(g3, 'numeric', 'Value', 0.2, 'Limits', [0 P.x_ref_max], ...
    'ValueChangedFcn', @(~,~) sendRef());
uilabel(g3, 'Text', 'Frequency [Hz]');
efFreq = uieditfield(g3, 'numeric', 'Value', 0.1, 'Limits', [0 5], ...
    'ValueChangedFcn', @(~,~) sendRef());

%% ---------------- LQR tuning ----------------
p4 = uipanel(R, 'Title', 'LQR tuning (up)');
g4 = uigridlayout(p4, [4 4]); g4.RowHeight = repmat({'fit'}, 1, 4);
uilabel(g4, 'Text', 'Qx'); efQx = uieditfield(g4, 'numeric', 'Value', P.Qup(1,1), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qθ'); efQt = uieditfield(g4, 'numeric', 'Value', P.Qup(3,3), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qẋ'); efQv = uieditfield(g4, 'numeric', 'Value', P.Qup(2,2), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'R');  efR  = uieditfield(g4, 'numeric', 'Value', P.Rup, 'Limits', [1e-6 Inf]);
bK = uibutton(g4, 'Text', 'Recompute K (live)', 'ButtonPushedFcn', @(~,~) redesign());
bK.Layout.Column = [1 4];
lblK = uilabel(g4, 'Text', kText(cp.P.K_up), 'FontName', 'Consolas');
lblK.Layout.Column = [1 4];

%% ---------------- Sensors / data ----------------
p5 = uipanel(R, 'Title', 'Sensors and data');
g5 = uigridlayout(p5, [2 2]); g5.RowHeight = {'fit', 'fit'};
uicheckbox(g5, 'Text', 'Encoder noise', 'Value', P.noise_on > 0, ...
    'ValueChangedFcn', @(s,~) cp.setParam('noise_on', double(s.Value)));
uibutton(g5, 'Text', 'Open model', 'ButtonPushedFcn', @(~,~) cp.openModel());
bExp = uibutton(g5, 'Text', 'Export last run → cp_res', 'ButtonPushedFcn', @(~,~) exportRes());
bExp.Layout.Column = [1 2];

%% ---------------- Status ----------------
p6 = uipanel(R, 'Title', 'Status');
g6 = uigridlayout(p6, [1 1]);
lblS = uilabel(g6, 'Text', 'Stopped', 'FontName', 'Consolas', 'WordWrap', 'on');

%% ---------------- Live plots ----------------
hA = cp_draw(axA, P);
nPts = Twin*cp.TelemetryRate*3;
lx  = animatedline(axX, 'Color', [0.00 0.45 0.74], 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lr  = animatedline(axX, 'Color', [0.47 0.67 0.19], 'LineStyle', '--', 'MaximumNumPoints', nPts);
lt  = animatedline(axT, 'Color', [0.85 0.33 0.10], 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lF  = animatedline(axF, 'Color', [0.49 0.18 0.56], 'MaximumNumPoints', nPts);
legend(axX, {'x', 'r'}, 'Location', 'northwest');

I = CartPole.TEL;
cp.clearCallbacks();
cp.addTelemetryCallback(@onTelemetry);
cp.addStopCallback(@onSimStopped);

fig.WindowKeyPressFcn   = @onKey;
fig.WindowKeyReleaseFcn = @onKeyUp;
fig.CloseRequestFcn     = @onClose;
uManual = 0; keyDown = false;

%% ======================= callbacks =======================
    function onStart(~, ~)
        th0 = deg2rad(efTh0.Value);
        if startsWith(ddIC.Value, 'Down'), th0 = pi; end
        cp.setInitialState([efX0.Value 0 th0 0]);
        cp.PacingRate = str2double(erase(ddRate.Value, 'x'));
        clearpoints(lx); clearpoints(lr); clearpoints(lt); clearpoints(lF);
        sendRef(); cp.setMode(ddMode.Value); cp.enable(cbEn.Value);
        cp.start();
        bStart.Enable = 'off'; bStop.Enable = 'on'; bPause.Enable = 'on';
        ddIC.Enable = 'off'; efTh0.Enable = 'off'; efX0.Enable = 'off'; ddRate.Enable = 'off';
    end

    function onPause(~, ~)
        if strcmp(get_param(cp.Model, 'SimulationStatus'), 'paused')
            cp.resume(); bPause.Text = '❚❚ Pause';
        else
            cp.pause(); bPause.Text = '▶ Resume';
        end
    end

    function onStop(~, ~)
        cp.stop();
    end

    function onSimStopped()
        if ~isvalid(fig), return; end
        bStart.Enable = 'on'; bStop.Enable = 'off'; bPause.Enable = 'off';
        bPause.Text = '❚❚ Pause';
        ddIC.Enable = 'on'; efTh0.Enable = 'on'; efX0.Enable = 'on'; ddRate.Enable = 'on';
        lblS.Text = sprintf('Stopped at t = %.2f s', cp.LastTime);
    end

    function onTelemetry(t, d)
        if ~isvalid(fig), return; end
        cp_draw(axA, P, hA, d(I.x), d(I.th), d(I.r));
        thd = rad2deg(mod(d(I.th) + pi, 2*pi) - pi);
        addpoints(lx, t, d(I.x)); addpoints(lr, t, d(I.r));
        addpoints(lt, t, thd);    addpoints(lF, t, d(I.Fact));
        xl = [max(0, t - Twin), max(Twin, t)];
        xlim(axX, xl); xlim(axT, xl); xlim(axF, xl);
        st = '';
        if d(I.tripped) > 0.5, st = '  ⚠ SAFETY: control cut off (untick/tick "enabled")'; end
        if d(I.mode) == 2
            if d(I.caught) > 0.5, st = [st '  [LQR caught]']; else, st = sprintf('%s  [swing-up, E = %.3f J]', st, d(I.E)); end
        end
        lblS.Text = sprintf('t = %6.2f s   mode %d\nx = %+.3f m   θ = %+6.1f°\nF = %+5.1f N   r = %+.2f m%s', ...
            t, d(I.mode), d(I.x), thd, d(I.Fact), d(I.r), st);
        axA.Title.String = sprintf('t = %.1f s', t);
        drawnow limitrate
    end

    function setManual(u, updateSlider)
        uManual = u;
        if nargin > 1 && updateSlider, slF.Value = u; end
        lblF.Text = sprintf('Manual F: %+.1f N', u);
        if ~keyDown, cp.setForce(u); end
    end

    function doPush()
        if cp.isRunning(), cp.push(efPush.Value, 0.1); end
    end

    function sendRef(offOverride)
        off = slOff.Value;
        if nargin > 0, off = offOverride; end
        lblOff.Text = sprintf('Offset: %+.2f m', off);
        cp.setRef(ddRef.Value, off, efAmp.Value, efFreq.Value);
    end

    function redesign()
        Q = cp.P.Qup; Q(1,1) = efQx.Value; Q(2,2) = efQv.Value; Q(3,3) = efQt.Value;
        cp.setParams(struct('Qup', Q, 'Rup', efR.Value));
        lblK.Text = kText(cp.P.K_up);
    end

    function exportRes()
        try
            res = cp.lastResult();
            assignin('base', 'cp_res', res);
            cp_plot_results(res, 'Last live run');
        catch err
            uialert(fig, ['No data yet: ' err.message], 'Export');
        end
    end

    function onKey(~, e)
        switch e.Key
            case 'leftarrow',  keyDown = true; cp.setForce(uManual - KeyForce);
            case 'rightarrow', keyDown = true; cp.setForce(uManual + KeyForce);
            case 'space',      doPush();
        end
    end

    function onKeyUp(~, e)
        if any(strcmp(e.Key, {'leftarrow', 'rightarrow'}))
            keyDown = false; cp.setForce(uManual);
        end
    end

    function onClose(~, ~)
        try, cp.stop(); catch, end
        cp.clearCallbacks();
        delete(fig);
    end
end

function s = kText(K)
s = sprintf('K = [%.1f  %.1f  %.1f  %.1f]', K);
end
