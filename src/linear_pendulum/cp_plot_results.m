function cp_plot_results(res, plotTitle)
%CP_PLOT_RESULTS  Standard plots of a cart-pole run.
if nargin < 2, plotTitle = 'Cart-pole run'; end
figure('Name', plotTitle, 'Color', 'w');
tl = tiledlayout(4, 1, 'TileSpacing', 'compact');
title(tl, plotTitle);

nexttile; plot(res.t, res.x, res.t, res.r, '--', res.t, res.xm, ':'); grid on
ylabel('x [m]'); legend('x true', 'reference', 'x measured', 'Location', 'best');

nexttile; plot(res.t, res.th_deg); grid on; ylabel('\theta [deg]');
yline(0, 'k:');

nexttile; plot(res.t, res.Fcmd, res.t, res.Fact); grid on
ylabel('F [N]'); legend('commanded', 'applied', 'Location', 'best');

nexttile; yyaxis left; plot(res.t, res.mode, res.t, res.caught, '--'); ylabel('mode / caught');
yyaxis right; plot(res.t, res.E); ylabel('E [J]'); grid on; xlabel('t [s]');
if any(res.tripped > 0.5)
    t1 = res.t(find(res.tripped > 0.5, 1));
    xline(t1, 'r', 'Safety: end of rail');
end
end
