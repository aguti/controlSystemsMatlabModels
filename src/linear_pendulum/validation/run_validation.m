function outDir = run_validation(outDir)
%RUN_VALIDATION  Runs the reference scenarios on the Simulink model and
%   stores each run as a CSV, so they can be compared against the Python
%   replica with compare_with_python.py.
%
%   run_validation                 -> writes to validation/results/
%   run_validation('some/folder')
%
%   CSV columns:
%     t x xd th_deg thd Fcmd Fact caught r tripped xm thm
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
save_ = @(name, res) writematrix([res.t res.x res.xd res.th_deg res.thd ...
    res.Fcmd res.Fact res.caught res.r res.tripped res.xm res.thm], ...
    fullfile(outDir, [name '.csv']));

cp_build_model();
cp = CartPole();

%% Matched conditions (no reference rate limiter)
cp.setParamRaw('ref_rate', 1e6);
cp.clearSignals(); cp.setRef('const', 0);

cp.setMode('lqr'); cp.setInitialState([0 0 0.15 0]);
save_('lqr_ic', cp.run(6));

[t, r] = stepSig(1, 0.3, 8);
cp.setInitialState([0 0 0 0]); cp.setRefSignal(t, r);
save_('lqr_step', cp.run(8));

cp.clearSignals(); cp.setRef('const', 0);
cp.setDisturbanceSignal([0 1 1+1e-4 1.1 1.1+1e-4 6]', [0 0 1 1 0 0]');
save_('lqr_push', cp.run(6));
cp.clearSignals();

cp.setMode('swingup'); cp.setInitialState([0 0 pi 0]);
save_('swingup', cp.run(10));

cp.setMode('pid'); cp.setInitialState([0 0 0.1 0]);
save_('pid_ic', cp.run(8));

[t, r] = stepSig(1, 0.3, 10);
cp.setInitialState([0 0 0 0]); cp.setRefSignal(t, r);
save_('pid_step', cp.run(10));

[t, r] = stepSig(1, 0.5, 8);
cp.setMode('crane'); cp.setInitialState([0 0 pi 0]); cp.setRefSignal(t, r);
save_('crane', cp.run(8));

Kn = cp.P.K_dn; Kn(3:4) = 0;            % no angle feedback -> PD on the cart only
cp.setParamRaw('K_dn', Kn);
save_('crane_nosway', cp.run(8));

%% Default conditions (with rate limiter)
cp = CartPole();
[t, r] = stepSig(1, 0.3, 8);
cp.setMode('lqr'); cp.setInitialState([0 0 0 0]); cp.setRefSignal(t, r);
save_('lqr_step_ratelim', cp.run(8));

[t, r] = stepSig(1, 0.5, 8);
cp.setMode('crane'); cp.setInitialState([0 0 pi 0]); cp.setRefSignal(t, r);
save_('crane_ratelim', cp.run(8));

%% Sine tracking with LQR
cp.clearSignals();
for f = [0.1 0.2 0.5]
    cp.setMode('lqr'); cp.setInitialState([0 0 0 0]); cp.setRef('sine', 0, 0.2, f);
    save_(sprintf('sine_%g', f), cp.run(30));
end

%% Encoder noise enabled
cp.setRef('const', 0); cp.setParam('noise_on', 1);
cp.setInitialState([0 0 0.15 0]);
save_('lqr_ic_noise', cp.run(6));

fprintf('Validation runs written to %s\n', outDir);
end
