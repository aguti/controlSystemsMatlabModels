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
