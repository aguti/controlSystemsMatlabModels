function outDir = run_validation(outDir)
%RUN_VALIDATION  Runs the reference scenarios on the ball and plate Simulink
%   model and stores each run as a CSV, so they can be compared against the
%   Python replica with compare_with_python.py.
%
%   run_validation                 -> writes to validation/results/
%   run_validation('some/folder')
%
%   CSV columns (SI units):
%     t x xd y yd al ald be bed Va Vb rx ry xm ym
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

save_ = @(name, res) writematrix([res.t res.x res.xd res.y res.yd res.al res.ald ...
    res.be res.bed res.Va res.Vb res.rx res.ry res.xm res.ym], ...
    fullfile(outDir, [name '.csv']));
tStep = [0 1 1+1e-4 6]'; rStep = [0 0; 0 0; 0.08 -0.05; 0.08 -0.05];
tTap  = [0 1 1+1e-4 1.05 1.05+1e-4 4]'; fTap = [0 0; 0 0; 0.2 0.2; 0.2 0.2; 0 0; 0 0];

bp_build_model();
bp = BallPlate();

%% Matched conditions (no reference rate limiter)
bp.setParamRaw('ref_rate', 1e6);
for m = {'lqr', 'cascade'}
    bp.setMode(m{1}); bp.clearSignals(); bp.setRef('point', [0 0]);
    bp.setInitialState([0.08 0 -0.05 0 0 0 0 0]);
    save_([m{1} '_ic'], bp.run(5));
    bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tStep, rStep);
    save_([m{1} '_step'], bp.run(6));
    bp.clearSignals(); bp.setRef('point', [0 0]);
    bp.setDisturbanceSignal(tTap, fTap);
    save_([m{1} '_tap'], bp.run(4));
    bp.clearSignals();
    bp.setInitialState([0.06 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.06, 0.2);
    save_([m{1} '_circle'], bp.run(15));
end

bp.setMode('cascade'); bp.setParam('Tcam', 0.04);
bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tStep, rStep);
save_('cascade_step_25fps', bp.run(6));
bp.setParam('Tcam', 0.02); bp.clearSignals();

bp.setMode('plate'); bp.setPlateAngle(deg2rad(-1), deg2rad(0.5));
bp.setRef('point', [0 0]); bp.setInitialState(zeros(8, 1));
save_('plate_tilt', bp.run(4));
bp.setPlateAngle(0, 0);

%% Default conditions (with rate limiter)
bp = BallPlate();
for m = {'lqr', 'cascade'}
    bp.setMode(m{1}); bp.setInitialState(zeros(8, 1)); bp.setRefSignal(tStep, rStep);
    save_([m{1} '_step_ratelim'], bp.run(6));
end
bp.clearSignals();
bp.setMode('lqr'); bp.setInitialState(zeros(8, 1)); bp.setRef('eight', [0 0], 0.07, 0.15);
save_('lqr_eight', bp.run(20));
bp.setInitialState([0.09 0 0 0 0 0 0 0]); bp.setRef('circle', [0 0], 0.09, 0.4);
save_('lqr_circle_fast', bp.run(12));

%% Sensor noise enabled
bp.setRef('point', [0 0]); bp.setParam('noise_on', 1);
bp.setInitialState(zeros(8, 1));
save_('lqr_noise', bp.run(6));

fprintf('Validation runs written to %s\n', outDir);
if nargout == 0, clear outDir; end
end
