function [V, info] = bb_controller_block(y, r, cmd, P)
%BB_CONTROLLER_BLOCK  Discrete ball and beam controller (period P.Ts).
%   Source code of the "Controller/Control law" block. If you edit it,
%   run bb_build_model again.
%
%   Inputs
%     y   = [x_meas; alpha_meas]   ball position sensor and beam encoder
%     r   = ball position reference [m]
%     cmd = [mode; enable; u_manual; alpha_manual]
%   Outputs
%     V    = voltage requested from the amplifier [V]
%     info = [mode; alpha_ref; integrator]
%
%   Modes
%     0  Open loop: V = u_manual (+ external signal u_ext)
%     1  Beam: PD servo of the beam angle to alpha_manual (ball free)
%     2  Cascade: PID on the ball (outer) -> alpha_ref -> PD on the beam (inner)
%     3  LQR with integral action on the ball position
%
%   Velocities are not measured: they are estimated with filtered derivatives.
%   With ff_on = 1 the ball weight torque on the beam is compensated:
%   cascade with the measured x, LQR with the equilibrium voltage at x = r.
%#codegen
persistent yp v I lastMode
if isempty(yp)
    yp = y; v = [0; 0]; I = 0; lastMode = -1;
end

mode = round(cmd(1)); en = cmd(2); uman = cmd(3); alman = cmd(4);

% --- Velocity estimation (first-order filtered derivatives) ---
a  = exp(-P.Ts./[P.tau_x; P.tau_v]);
v  = a.*v + (1 - a).*(y - yp)/P.Ts;
yp = y;

x = y(1); al = y(2); xd = v(1); ald = v(2);
e = x - r;

if mode ~= lastMode || en < 0.5          % reset on mode change / disable
    I = 0; lastMode = mode;
end

alr = 0; Vc = 0;
switch mode
    case 1  % ---------------- Beam angle servo ----------
        alr = alman;
        Vc  = P.Kp_a*(alr - al) - P.Kd_a*ald;

    case 2  % ---------------- Cascade PID / PD ----------
        if abs(e) < P.e_int
            I = min(max(I + e*P.Ts, -P.I_max), P.I_max);
        end
        alr = min(max(P.Kp_x*e + P.Kd_x*xd + P.Ki_x*I, -P.al_ref_max), P.al_ref_max);
        Vc  = P.Kp_a*(alr - al) - P.Kd_a*ald + P.ff_on*P.m*P.g*x/P.kv;

    case 3  % ---------------- LQR + integral ------------
        if abs(e) < P.e_int
            I = min(max(I + e*P.Ts, -P.I_max), P.I_max);
        end
        Vc = -P.K*[e; xd; al; ald; I] + P.ff_on*P.m*P.g*r/P.kv;

    otherwise
        Vc = 0;
end

if en < 0.5
    Vc = 0;
end

V    = min(max(Vc + uman, -P.Vmax), P.Vmax);
info = [mode; alr; I];
end
