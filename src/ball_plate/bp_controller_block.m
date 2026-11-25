function [V, info] = bp_controller_block(y, r, cmd, P)
%BP_CONTROLLER_BLOCK  Discrete ball and plate controller (period P.Ts).
%   Source code of the "Controller/Control law" block. If you edit it,
%   run bp_build_model again.
%
%   Inputs
%     y   = [x_cam; y_cam; alpha_meas; beta_meas]  camera + plate encoders
%     r   = [rx; ry] ball position reference [m]
%     cmd = [mode; enable; Va_manual; Vb_manual; alpha_manual; beta_manual]
%   Outputs
%     V    = [Va; Vb] voltages requested from the amplifier [V]
%     info = [mode; alpha_ref; beta_ref; Ix; Iy]
%
%   Modes
%     0  Open loop: V = manual voltages (+ external signal u_ext)
%     1  Plate: PD servo of both plate angles to (alpha_manual, beta_manual)
%     2  Cascade: PID on the ball (outer, camera rate) -> plate angle
%        references -> PD on the plate angles (inner, every Ts)
%     3  LQR with integral action, one per axis (x -> alpha, y -> beta)
%
%   The camera delivers a new frame every Tcam (Ncam = Tcam/Ts controller
%   samples). The ball velocity and the outer loops are updated only when a
%   new frame arrives; the plate loops run every Ts.
%#codegen
persistent n pp vb ap va I alr lastMode
if isempty(n)
    n = 0; pp = [y(1); y(2)]; vb = [0; 0]; ap = [y(3); y(4)]; va = [0; 0];
    I = [0; 0]; alr = [0; 0]; lastMode = -1;
end

mode = round(cmd(1)); en = cmd(2);
uman = [cmd(3); cmd(4)]; angman = [cmd(5); cmd(6)];
p = [y(1); y(2)]; ang = [y(3); y(4)];

% --- Plate angular velocities: filtered derivative every Ts ---
aa = exp(-P.Ts/P.tau_v);
va = aa*va + (1 - aa)*(ang - ap)/P.Ts;
ap = ang;

% --- Ball velocity: filtered derivative once per camera frame ---
Ncam = max(1, round(P.Tcam/P.Ts));
newFrame = mod(n, Ncam) == 0;
n = n + 1;
if newFrame
    ac = exp(-P.Tcam/P.tau_c);
    vb = ac*vb + (1 - ac)*(p - pp)/P.Tcam;
    pp = p;
end

if mode ~= lastMode || en < 0.5          % reset on mode change / disable
    I = [0; 0]; alr = [0; 0]; lastMode = mode;
end

e  = p - [r(1); r(2)];
Vc = [0; 0];
switch mode
    case 1  % ---------------- Plate angle servo ---------
        alr = angman;
        Vc  = P.Kp_a*(alr - ang) - P.Kd_a*va;

    case 2  % ---------------- Cascade PID / PD ----------
        if newFrame
            for i = 1:2
                if abs(e(i)) < P.e_int
                    I(i) = min(max(I(i) + e(i)*P.Tcam, -P.I_max), P.I_max);
                end
            end
            alr = min(max(P.Kp_x*e + P.Kd_x*vb + P.Ki_x*I, -P.al_ref_max), P.al_ref_max);
        end
        Vc = P.Kp_a*(alr - ang) - P.Kd_a*va + P.ff_on*P.m*P.g*p/P.kv;

    case 3  % ---------------- LQR + integral, per axis --
        if newFrame
            for i = 1:2
                if abs(e(i)) < P.e_int
                    I(i) = min(max(I(i) + e(i)*P.Tcam, -P.I_max), P.I_max);
                end
            end
        end
        alr = [0; 0];
        Vc = [-P.Kx*[e(1); vb(1); ang(1); va(1); I(1)];
              -P.Ky*[e(2); vb(2); ang(2); va(2); I(2)]] + P.ff_on*P.m*P.g*[r(1); r(2)]/P.kv;

    otherwise
        Vc = [0; 0];
end

if en < 0.5
    Vc = [0; 0];
end

V    = min(max(Vc + uman, -P.Vmax), P.Vmax);
info = [mode; alr; I];
end
