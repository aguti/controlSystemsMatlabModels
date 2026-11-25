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
