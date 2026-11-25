function rp_plot_results(res, plotTitle)
%RP_PLOT_RESULTS  Standard plots of a rotary pendulum run (angles in degrees).
if nargin < 2, plotTitle = 'Rotary pendulum run'; end
figure('Name', plotTitle, 'Color', 'w');
tl = tiledlayout(4, 1, 'TileSpacing', 'compact');
title(tl, plotTitle);

nexttile; plot(res.t, res.th_deg, res.t, res.r_deg, '--', res.t, rad2deg(res.thm), ':'); grid on
ylabel('\theta [deg]'); legend('arm', 'reference', 'measured', 'Location', 'best');

nexttile; plot(res.t, res.al_deg); grid on; ylabel('\alpha [deg]');
yline(0, 'k:');

nexttile; plot(res.t, res.Vcmd, res.t, res.Vact); grid on
ylabel('V [V]'); legend('commanded', 'applied', 'Location', 'best');

nexttile; yyaxis left; plot(res.t, res.mode, res.t, res.caught, '--'); ylabel('mode / caught');
yyaxis right; plot(res.t, res.E*1e3); ylabel('E [mJ]'); grid on; xlabel('t [s]');
if any(res.tripped > 0.5)
    t1 = res.t(find(res.tripped > 0.5, 1));
    xline(t1, 'r', 'Safety: arm out of range');
end
end
