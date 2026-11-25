function bp = bp_gui(bp)
%BP_GUI  Live visual interface of the ball and plate.
%
%   bp_gui              creates a new BallPlate and opens the panel
%   bp = bp_gui(bp)     uses an existing BallPlate object (you can keep
%                       sending it commands from the command line
%                       while the GUI is open)
%
%   The GUI shows positions in cm and angles in degrees; the code
%   interface uses metres and radians.
%   - Click on the camera (top) view to move the reference point.
%   - Keyboard (window focused): arrows = tap the ball in that direction.
%   - The 3D view can be rotated with the mouse or set from the "View" list.

if nargin < 1 || isempty(bp), bp = BallPlate(); end
P = bp.P;
Twin = 10;                                    % plot time window [s]
xMaxCm = 100*P.x_max;

%% ---------------- Window and layout ----------------
fig = uifigure('Name', 'Ball and plate — live Simulink', ...
    'Position', [40 40 1360 840]);
G = uigridlayout(fig, [1 2]);
G.ColumnWidth = {'1x', 340};

L = uigridlayout(G, [4 1]);
L.RowHeight = {'2.6x', '1x', '1x', '1x'};
Top = uigridlayout(L, [1 2]); Top.ColumnWidth = {'1.5x', '1x'}; Top.Padding = [0 0 0 0];
axA = uiaxes(Top); title(axA, 'Ball and plate');
axT = uiaxes(Top); title(axT, 'Camera view (click to set the target)');
axX = uiaxes(L); ylabel(axX, 'x, y [cm]'); grid(axX, 'on');
axB = uiaxes(L); ylabel(axB, 'tilt [deg]'); grid(axB, 'on');
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
uilabel(g1, 'Text', 'x0, y0 [cm]');
efX0 = uieditfield(g1, 'numeric', 'Value', 100*P.x0(1), 'Limits', [-xMaxCm xMaxCm]);
efY0 = uieditfield(g1, 'numeric', 'Value', 100*P.x0(3), 'Limits', [-xMaxCm xMaxCm]);
uilabel(g1, 'Text', 'Speed');
ddRate = uidropdown(g1, 'Items', {'0.25x', '0.5x', '1x', '2x'}, 'Value', '1x');
ddRate.Layout.Column = [2 3];
uilabel(g1, 'Text', 'View');
ddView = uidropdown(g1, 'Items', {'3D', 'Top', 'Front (α)', 'Side (β)'}, 'ItemsData', {'iso', 'top', 'front', 'side'}, ...
    'Value', 'iso', 'ValueChangedFcn', @(s,~) bp_view(axA, s.Value));
ddView.Layout.Column = [2 3];

%% ---------------- Control ----------------
p2 = uipanel(R, 'Title', 'Control');
g2 = uigridlayout(p2, [6 3]); g2.RowHeight = repmat({'fit'}, 1, 6);
g2.ColumnWidth = {95, '1x', '1x'};
uilabel(g2, 'Text', 'Mode');
modeItems = {'0  Open loop (manual V)', '1  Plate angle servo', ...
             '2  Cascade PID + PD', '3  LQR + integral'};
ddMode = uidropdown(g2, 'Items', modeItems, 'ItemsData', 0:3, ...
    'Value', bp.CmdCtrl(1), 'ValueChangedFcn', @(s,~) bp.setMode(s.Value));
ddMode.Layout.Column = [2 3];
cbEn = uicheckbox(g2, 'Text', 'Control enabled', 'Value', bp.CmdCtrl(2) > 0, ...
    'ValueChangedFcn', @(s,~) bp.enable(s.Value));
cbEn.Layout.Column = [1 2];
cbFF = uicheckbox(g2, 'Text', 'Weight ff', 'Value', P.ff_on > 0, ...
    'ValueChangedFcn', @(s,~) bp.setParam('ff_on', double(s.Value)));
uilabel(g2, 'Text', 'Manual Va, Vb');
efVa = uieditfield(g2, 'numeric', 'Value', 0, 'Limits', [-P.Vmax P.Vmax], 'ValueChangedFcn', @(~,~) sendV());
efVb = uieditfield(g2, 'numeric', 'Value', 0, 'Limits', [-P.Vmax P.Vmax], 'ValueChangedFcn', @(~,~) sendV());
lblA = uilabel(g2, 'Text', 'Tilt α, β [°]');
alMaxDeg = floor(rad2deg(P.al_max));
slA = uislider(g2, 'Limits', [-alMaxDeg alMaxDeg], 'Value', 0, 'MajorTicks', [-15 0 15], ...
    'ValueChangingFcn', @(~,e) sendTilt(e.Value, slB.Value), 'ValueChangedFcn', @(~,~) sendTilt());
slB = uislider(g2, 'Limits', [-alMaxDeg alMaxDeg], 'Value', 0, 'MajorTicks', [-15 0 15], ...
    'ValueChangingFcn', @(~,e) sendTilt(slA.Value, e.Value), 'ValueChangedFcn', @(~,~) sendTilt());
uilabel(g2, 'Text', 'Tap [N]');
efPush = uieditfield(g2, 'numeric', 'Value', 0.2, 'Limits', [0 2]);
uilabel(g2, 'Text', '(arrow keys)');
uibutton(g2, 'Text', 'Tap ▶ (+x)', 'ButtonPushedFcn', @(~,~) doPush([1 0]));
b2 = uibutton(g2, 'Text', 'Tap ▲ (+y)', 'ButtonPushedFcn', @(~,~) doPush([0 1]));
b2.Layout.Column = [2 3];

%% ---------------- Reference ----------------
p3 = uipanel(R, 'Title', 'Ball reference');
g3 = uigridlayout(p3, [4 3]); g3.RowHeight = repmat({'fit'}, 1, 4);
g3.ColumnWidth = {95, '1x', '1x'};
uilabel(g3, 'Text', 'Type');
ddRef = uidropdown(g3, 'Items', {'Point', 'Circle', 'Square (corners)', 'Figure of eight', 'External (ref_ext)'}, ...
    'ItemsData', 0:4, 'Value', 0, 'ValueChangedFcn', @(~,~) sendRef());
ddRef.Layout.Column = [2 3];
uilabel(g3, 'Text', 'Centre [cm]');
efCx = uieditfield(g3, 'numeric', 'Value', 0, 'Limits', 100*P.x_ref_max*[-1 1], 'ValueChangedFcn', @(~,~) sendRef());
efCy = uieditfield(g3, 'numeric', 'Value', 0, 'Limits', 100*P.x_ref_max*[-1 1], 'ValueChangedFcn', @(~,~) sendRef());
uilabel(g3, 'Text', 'Amplitude [cm]');
efAmp = uieditfield(g3, 'numeric', 'Value', 6, 'Limits', [0 100*P.x_ref_max], ...
    'ValueChangedFcn', @(~,~) sendRef());
efAmp.Layout.Column = [2 3];
uilabel(g3, 'Text', 'Frequency [Hz]');
efFreq = uieditfield(g3, 'numeric', 'Value', 0.2, 'Limits', [0 5], ...
    'ValueChangedFcn', @(~,~) sendRef());
efFreq.Layout.Column = [2 3];

%% ---------------- Tuning ----------------
p4 = uipanel(R, 'Title', 'Tuning (applied live)');
g4 = uigridlayout(p4, [7 4]); g4.RowHeight = repmat({'fit'}, 1, 7);
lC = uilabel(g4, 'Text', 'Cascade (ball PID)', 'FontWeight', 'bold'); lC.Layout.Column = [1 4];
uilabel(g4, 'Text', 'Kp'); efKp = uieditfield(g4, 'numeric', 'Value', P.Kp_x, 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Kd'); efKd = uieditfield(g4, 'numeric', 'Value', P.Kd_x, 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Ki'); efKi = uieditfield(g4, 'numeric', 'Value', P.Ki_x, 'Limits', [0 Inf]);
lQ = uilabel(g4, 'Text', 'LQR weights', 'FontWeight', 'bold'); lQ.Layout.Column = [3 4];
uilabel(g4, 'Text', 'Qx');   efQx = uieditfield(g4, 'numeric', 'Value', P.Q(1,1), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qα');   efQa = uieditfield(g4, 'numeric', 'Value', P.Q(3,3), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'Qint'); efQi = uieditfield(g4, 'numeric', 'Value', P.Q(5,5), 'Limits', [0 Inf]);
uilabel(g4, 'Text', 'R');    efR  = uieditfield(g4, 'numeric', 'Value', P.R, 'Limits', [1e-6 Inf]);
bK = uibutton(g4, 'Text', 'Apply gains / recompute K', 'ButtonPushedFcn', @(~,~) redesign());
bK.Layout.Column = [1 4];
lblK = uilabel(g4, 'Text', kText(bp.P.Kx), 'FontName', 'Consolas');
lblK.Layout.Column = [1 4];

%% ---------------- Sensors / data ----------------
p5 = uipanel(R, 'Title', 'Sensors and data');
g5 = uigridlayout(p5, [3 2]); g5.RowHeight = {'fit', 'fit', 'fit'};
uicheckbox(g5, 'Text', 'Sensor noise', 'Value', P.noise_on > 0, ...
    'ValueChangedFcn', @(s,~) bp.setParam('noise_on', double(s.Value)));
uibutton(g5, 'Text', 'Open model', 'ButtonPushedFcn', @(~,~) bp.openModel());
uilabel(g5, 'Text', 'Camera (next start)');
ddCam = uidropdown(g5, 'Items', {'25 fps', '50 fps', '100 fps', '250 fps'}, ...
    'ItemsData', [0.04 0.02 0.01 0.004], 'Value', P.Tcam, ...
    'ValueChangedFcn', @(s,~) bp.setParam('Tcam', s.Value));
bExp = uibutton(g5, 'Text', 'Export last run → bp_res', 'ButtonPushedFcn', @(~,~) exportRes());
bExp.Layout.Column = [1 2];

%% ---------------- Status ----------------
p6 = uipanel(R, 'Title', 'Status');
g6 = uigridlayout(p6, [1 1]);
lblS = uilabel(g6, 'Text', 'Stopped', 'FontName', 'Consolas', 'WordWrap', 'on');

%% ---------------- Live plots ----------------
hA = bp_draw(axA, P);
axA.XTickLabel = {}; axA.YTickLabel = {}; axA.ZTickLabel = {};
xlabel(axA, ''); ylabel(axA, ''); zlabel(axA, '');
hT = bp_draw_top(axT, P);
axT.ButtonDownFcn = @onClickTop;
showState(P.x0(1), P.x0(3), 0, 0, 0, 0);
nPts = Twin*bp.TelemetryRate*3;
cx = [0.85 0.33 0.10]; cy = [0.00 0.45 0.74];
lx  = animatedline(axX, 'Color', cx, 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lrx = animatedline(axX, 'Color', cx, 'LineStyle', '--', 'MaximumNumPoints', nPts);
ly  = animatedline(axX, 'Color', cy, 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lry = animatedline(axX, 'Color', cy, 'LineStyle', '--', 'MaximumNumPoints', nPts);
la  = animatedline(axB, 'Color', cx, 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lb  = animatedline(axB, 'Color', cy, 'MaximumNumPoints', nPts, 'LineWidth', 1.2);
lVa = animatedline(axV, 'Color', cx, 'MaximumNumPoints', nPts);
lVb = animatedline(axV, 'Color', cy, 'MaximumNumPoints', nPts);
legend(axX, {'x', 'r_x', 'y', 'r_y'}, 'Location', 'northwest', 'NumColumns', 2);
legend(axB, {'\alpha', '\beta'}, 'Location', 'northwest');
legend(axV, {'V_a', 'V_b'}, 'Location', 'northwest');
try, set([axX axB axV], 'YLimitMethod', 'padded'); catch, end   % R2021a+

I = BallPlate.TEL;
bp.clearCallbacks();
bp.addTelemetryCallback(@onTelemetry);
bp.addStopCallback(@onSimStopped);

fig.WindowKeyPressFcn = @onKey;
fig.CloseRequestFcn   = @onClose;
efX0.ValueChangedFcn  = @(~,~) previewIC();
efY0.ValueChangedFcn  = @(~,~) previewIC();

%% ======================= callbacks =======================
    function showState(x, y, al, be, rx, ry)
        bp_draw(axA, P, hA, x, y, al, be, rx, ry);
        bp_draw_top(axT, P, hT, x, y, rx, ry);
    end

    function clearTrails()
        set(hA.trail, 'XData', nan, 'YData', nan, 'ZData', nan);
        set(hT.trail, 'XData', nan, 'YData', nan);
    end

    function previewIC()
        if bp.isRunning(), return; end
        clearTrails();
        showState(efX0.Value/100, efY0.Value/100, 0, 0, efCx.Value/100, efCy.Value/100);
        clearTrails();
    end

    function onStart(~, ~)
        bp.setInitialState([efX0.Value/100 0 efY0.Value/100 0 0 0 0 0]);
        bp.PacingRate = str2double(erase(ddRate.Value, 'x'));
        for l = [lx lrx ly lry la lb lVa lVb], clearpoints(l); end
        clearTrails();
        sendRef(); bp.setMode(ddMode.Value); bp.enable(cbEn.Value);
        bp.start();
        bStart.Enable = 'off'; bStop.Enable = 'on'; bPause.Enable = 'on';
        efX0.Enable = 'off'; efY0.Enable = 'off'; ddRate.Enable = 'off'; ddCam.Enable = 'off';
    end

    function onPause(~, ~)
        if strcmp(get_param(bp.Model, 'SimulationStatus'), 'paused')
            bp.resume(); bPause.Text = '❚❚ Pause';
        else
            bp.pause(); bPause.Text = '▶ Resume';
        end
    end

    function onStop(~, ~)
        bp.stop();
    end

    function onSimStopped()
        if ~isvalid(fig), return; end
        bStart.Enable = 'on'; bStop.Enable = 'off'; bPause.Enable = 'off';
        bPause.Text = '❚❚ Pause';
        efX0.Enable = 'on'; efY0.Enable = 'on'; ddRate.Enable = 'on'; ddCam.Enable = 'on';
        lblS.Text = sprintf('Stopped at t = %.2f s', bp.LastTime);
    end

    function onTelemetry(t, d)
        if ~isvalid(fig), return; end
        showState(d(I.x), d(I.y), d(I.al), d(I.be), d(I.rx), d(I.ry));
        addpoints(lx, t, 100*d(I.x)); addpoints(lrx, t, 100*d(I.rx));
        addpoints(ly, t, 100*d(I.y)); addpoints(lry, t, 100*d(I.ry));
        addpoints(la, t, rad2deg(d(I.al))); addpoints(lb, t, rad2deg(d(I.be)));
        addpoints(lVa, t, d(I.Va)); addpoints(lVb, t, d(I.Vb));
        xl = [max(0, t - Twin), max(Twin, t)];
        xlim(axX, xl); xlim(axB, xl); xlim(axV, xl);
        st = '';
        if max(abs([d(I.x) d(I.y)])) >= P.x_max - 1e-3, st = '  ⚠ ball against the rim'; end
        e = 100*hypot(d(I.x) - d(I.rx), d(I.y) - d(I.ry));
        lblS.Text = sprintf('t = %6.2f s   mode %d\nball (%+5.1f, %+5.1f) cm   error %.1f cm\nα = %+5.1f°  β = %+5.1f°%s', ...
            t, d(I.mode), 100*d(I.x), 100*d(I.y), e, rad2deg(d(I.al)), rad2deg(d(I.be)), st);
        axA.Title.String = sprintf('t = %.1f s', t);
        drawnow nocallbacks   % synchronous, so the adaptive throttle sees its cost
    end

    function sendV()
        bp.setVoltage(efVa.Value, efVb.Value);
    end

    function sendTilt(aDeg, bDeg)
        if nargin < 2, aDeg = slA.Value; bDeg = slB.Value; end
        lblA.Text = sprintf('Tilt %+.0f°, %+.0f°', aDeg, bDeg);
        bp.setPlateAngle(deg2rad(aDeg), deg2rad(bDeg));
    end

    function doPush(dirn)
        if bp.isRunning(), bp.push(efPush.Value*dirn, 0.05); end
    end

    function onClickTop(~, e)
        p = e.IntersectionPoint(1:2);
        m = 100*P.x_ref_max;
        efCx.Value = max(min(round(100*p(1), 1), m), -m);
        efCy.Value = max(min(round(100*p(2), 1), m), -m);
        sendRef();
    end

    function sendRef()
        bp.setRef(ddRef.Value, [efCx.Value efCy.Value]/100, efAmp.Value/100, efFreq.Value);
        if ~bp.isRunning()
            set(hT.ref, 'XData', efCx.Value/100, 'YData', efCy.Value/100);
            previewIC();
        end
    end

    function redesign()
        Q = bp.P.Q; Q(1,1) = efQx.Value; Q(3,3) = efQa.Value; Q(5,5) = efQi.Value;
        bp.setParams(struct('Q', Q, 'R', efR.Value, ...
            'Kp_x', efKp.Value, 'Kd_x', efKd.Value, 'Ki_x', efKi.Value));
        lblK.Text = kText(bp.P.Kx);
    end

    function exportRes()
        try
            res = bp.lastResult();
            assignin('base', 'bp_res', res);
            bp_plot_results(res, 'Last live run');
        catch err
            uialert(fig, ['No data yet: ' err.message], 'Export');
        end
    end

    function onKey(~, e)
        switch e.Key
            case 'leftarrow',  doPush([-1 0]);
            case 'rightarrow', doPush([1 0]);
            case 'uparrow',    doPush([0 1]);
            case 'downarrow',  doPush([0 -1]);
        end
    end

    function onClose(~, ~)
        try, bp.stop(); catch, end
        bp.clearCallbacks();
        delete(fig);
    end
end

function s = kText(K)
s = sprintf('Kx = [%.1f %.1f %.1f %.2f %.1f]', K);
end
