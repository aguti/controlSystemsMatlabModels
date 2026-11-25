function outDir = run_validation(outDir)
%RUN_VALIDATION  Runs the reference scenarios on the rotary pendulum Simulink
%   model and stores each run as a CSV, so they can be compared against the
%   Python replica with compare_with_python.py.
%
%   run_validation                 -> writes to validation/results/
%   run_validation('some/folder')
%
%   CSV columns (angles in rad):
%     t th thd al ald Vcmd Vact caught r tripped thm alm
%
%   Scenarios "matched" to the Python replica run with the reference rate
%   limiter disabled (the replica does not model it). The "*_ratelim"
%   scenarios use the default parameters.
%
%   Then, from a shell:
%     python3 compare_with_python.py results

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1 || isempty(outDir), outDir = fullfile(here, 'results'); end
if ~exist(outDir, 'dir'), mkdir(outDir); end

stepSig = @(t0, A, T) deal([0 t0 t0+1e-4 T]', [0 0 A A]');
save_ = @(name, res) writematrix([res.t res.th res.thd res.al res.ald ...
    res.Vcmd res.Vact res.caught res.r res.tripped res.thm res.alm], ...
    fullfile(outDir, [name '.csv']));

rp_build_model();
rp = RotaryPendulum();
d45 = deg2rad(45);

%% Matched conditions (no reference rate limiter)
rp.setParamRaw('ref_rate', 1e6);
rp.clearSignals(); rp.setRef('const', 0);

rp.setMode('lqr'); rp.setInitialState([0 0 deg2rad(10) 0]);
save_('lqr_ic', rp.run(4));

[t, r] = stepSig(1, d45, 6);
rp.setInitialState([0 0 0 0]); rp.setRefSignal(t, r);
save_('lqr_step', rp.run(6));

rp.clearSignals(); rp.setRef('const', 0);
rp.setDisturbanceSignal([0 1 1+1e-4 1.05 1.05+1e-4 4]', [0 0 0.1 0.1 0 0]');
save_('lqr_push', rp.run(4));
rp.clearSignals();

rp.setMode('swingup'); rp.setInitialState([0 0 pi 0]);
save_('swingup', rp.run(8));

rp.setMode('pid'); rp.setInitialState([0 0 deg2rad(10) 0]);
save_('pid_ic', rp.run(4));

[t, r] = stepSig(1, d45, 6);
rp.setInitialState([0 0 0 0]); rp.setRefSignal(t, r);
save_('pid_step', rp.run(6));

rp.setMode('down'); rp.setInitialState([0 0 pi 0]); rp.setRefSignal(t, r);
save_('down_step', rp.run(6));

Kn = rp.P.K_dn; Kn(3:4) = 0;            % no pendulum feedback -> PD on the arm only
rp.setParamRaw('K_dn', Kn);
save_('down_nosway', rp.run(6));

%% Default conditions (with rate limiter)
rp = RotaryPendulum();
[t, r] = stepSig(1, d45, 6);
rp.setMode('lqr'); rp.setInitialState([0 0 0 0]); rp.setRefSignal(t, r);
save_('lqr_step_ratelim', rp.run(6));

%% Sine tracking with LQR (+-45 deg)
rp.clearSignals();
for f = [0.2 0.5 1]
    rp.setMode('lqr'); rp.setInitialState([0 0 0 0]); rp.setRef('sine', 0, d45, f);
    save_(sprintf('sine_%g', f), rp.run(20));
end

%% Encoder noise enabled
rp.setRef('const', 0); rp.setParam('noise_on', 1);
rp.setInitialState([0 0 deg2rad(10) 0]);
save_('lqr_ic_noise', rp.run(4));

fprintf('Validation runs written to %s\n', outDir);
if nargout == 0, clear outDir; end
end
