function outDir = run_validation(outDir)
%RUN_VALIDATION  Runs the reference scenarios on the ball and beam Simulink
%   model and stores each run as a CSV, so they can be compared against the
%   Python replica with compare_with_python.py.
%
%   run_validation                 -> writes to validation/results/
%   run_validation('some/folder')
%
%   CSV columns (SI units):
%     t x xd al ald Vcmd Vact r alr I xm alm
%
%   Scenarios "matched" to the Python replica run with the reference rate
%   limiter disabled (the replica does not model it). The "*_ratelim" and
%   "sine_*" scenarios use the default parameters.
%
%   Then, from a shell:
%     python3 compare_with_python.py results

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1 || isempty(outDir), outDir = fullfile(here, 'results'); end
if ~exist(outDir, 'dir'), mkdir(outDir); end

stepSig = @(t0, A, T) deal([0 t0 t0+1e-4 T]', [0 0 A A]');
save_ = @(name, res) writematrix([res.t res.x res.xd res.al res.ald ...
    res.Vcmd res.Vact res.r res.alr res.I res.xm res.alm], ...
    fullfile(outDir, [name '.csv']));

bb_build_model();
bb = BallBeam();
tap = {[0 1 1+1e-4 1.05 1.05+1e-4 4]', [0 0 0.2 0.2 0 0]'};

%% Matched conditions (no reference rate limiter)
bb.setParamRaw('ref_rate', 1e6);
for m = {'lqr', 'cascade'}
    bb.setMode(m{1}); bb.clearSignals(); bb.setRef('const', 0);
    bb.setInitialState([0.1 0 0 0]);
    save_([m{1} '_ic'], bb.run(5));
    [t, r] = stepSig(1, 0.1, 6);
    bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
    save_([m{1} '_step'], bb.run(6));
    bb.clearSignals(); bb.setRef('const', 0);
    bb.setDisturbanceSignal(tap{:});
    save_([m{1} '_tap'], bb.run(4));
end
bb.clearSignals();

[t, r] = stepSig(1, 0.1, 6);
bb.setMode('cascade'); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
bb.setParamRaw('ff_on', 0); bb.setParamRaw('Ki_x', 0);
save_('cascade_noff', bb.run(6));
bb.setParamRaw('ff_on', 1); bb.setParamRaw('Ki_x', 0.1);
bb.clearSignals(); bb.setRef('const', 0);

bb.setMode('beam'); bb.setBeamAngle(deg2rad(-2)); bb.setInitialState([0 0 0 0]);
save_('beam_tilt', bb.run(3));
bb.setBeamAngle(0);

%% Default conditions (with rate limiter)
bb = BallBeam();
[t, r] = stepSig(1, 0.1, 6);
for m = {'lqr', 'cascade'}
    bb.setMode(m{1}); bb.setInitialState([0 0 0 0]); bb.setRefSignal(t, r);
    save_([m{1} '_step_ratelim'], bb.run(6));
end

%% Sine tracking (+-10 cm)
bb.clearSignals();
for m = {'lqr', 'cascade'}
    for f = [0.1 0.25 0.5]
        bb.setMode(m{1}); bb.setInitialState([0 0 0 0]); bb.setRef('sine', 0, 0.1, f);
        save_(sprintf('sine_%s_%g', m{1}, f), bb.run(20));
    end
end

%% Sensor noise enabled
bb.setMode('lqr'); bb.setRef('const', 0); bb.setParam('noise_on', 1);
bb.setInitialState([0 0 0 0]);
save_('lqr_noise', bb.run(6));

fprintf('Validation runs written to %s\n', outDir);
if nargout == 0, clear outDir; end
end
