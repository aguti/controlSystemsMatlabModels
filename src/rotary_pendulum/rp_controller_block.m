function [V, info] = rp_controller_block(y, r, cmd, P)
%RP_CONTROLLER_BLOCK  Discrete rotary pendulum controller (period P.Ts).
%   Source code of the "Controller/Control law" block. If you edit it,
%   run rp_build_model again.
%
%   Inputs
%     y   = [theta_meas; alpha_meas]  encoder measurements (angles only)
%     r   = arm angle reference [rad]
%     cmd = [mode; enable; u_manual]
%   Outputs
%     V    = voltage requested from the amplifier [V]
%     info = [mode; energy; caught; safety_trip]
%
%   Modes
%     0  Open loop: V = u_manual (+ external signal u_ext)
%     1  LQR with the pendulum up (arm tracks r)
%     2  Energy-based swing-up + LQR catch
%     3  PID on the pendulum angle + PD on the arm (pendulum up)
%     4  Down: pendulum hanging, positions the arm damping the sway
%
%   Velocities are not measured: they are estimated with a filtered derivative.
%#codegen
persistent yp v I caught tripped lastMode
if isempty(yp)
    yp = y; v = [0; 0]; I = 0; caught = 0; tripped = 0; lastMode = -1;
end

mode = round(cmd(1)); en = cmd(2); uman = cmd(3);

% --- Velocity estimation (first-order filtered derivative) ---
a  = exp(-P.Ts/P.tau_v);
v  = a*v + (1 - a)*(y - yp)/P.Ts;
yp = y;

th = y(1); al = y(2); thd = v(1); ald = v(2);
alw = mod(al + pi, 2*pi) - pi;           % angle wrapped to [-pi, pi)

if mode ~= lastMode                       % reset on mode change
    I = 0; caught = 0; tripped = 0; lastMode = mode;
end
if en < 0.5
    tripped = 0;                          % disabling re-arms the safety latch
end

E = 0; Vc = 0;
switch mode
    case 1  % ---------------- LQR up --------------------
        Vc = -P.K_up*[th - r; thd; alw; ald];

    case 2  % ---------------- Swing-up + LQR ------------
        if caught > 0.5 && abs(alw) > P.al_release
            caught = 0;
        end
        if caught < 0.5 && abs(alw) < P.al_catch
            caught = 1;
        end
        if caught > 0.5
            Vc = -P.K_up*[th - r; thd; alw; ald];
        else
            c = cos(al); sn = sin(al); hc = P.mp*P.Lr*P.lp;
            E   = 0.5*P.Ja*ald^2 + P.mp*P.g*P.lp*(c - 1);    % E = 0 up at rest
            Eref = P.E_ref*2*P.mp*P.g*P.lp;                   % slightly above upright
            acc = P.k_E*(E - Eref)*ald*c - P.kx_sw*(th - r) - P.kv_sw*thd;
            if abs(ald) < 0.05 && c < -0.99                   % kick-off from rest
                acc = acc + 0.3*P.a_max;
            end
            acc = min(max(acc, -P.a_max), P.a_max);
            % Inverse dynamics: torque, then voltage, for the desired arm acceleration
            aldd = (P.Ja*sn*c*thd^2 + P.mp*P.g*P.lp*sn - P.Dp*ald - hc*c*acc)/P.Ja;
            tau  = (P.J0 + P.Ja*sn^2)*acc + 2*P.Ja*sn*c*ald*thd - hc*sn*ald^2 ...
                 + hc*c*aldd + P.Dr*thd;
            Vc = tau*P.Rm/P.kt + P.km*thd;
        end

    case 3  % ---------------- PID pendulum + PD arm -----
        I  = min(max(I + alw*P.Ts, -P.I_max), P.I_max);
        Vc = P.Kp_al*alw + P.Ki_al*I + P.Kd_al*ald ...
           + P.Kp_th*(th - r) + P.Kd_th*thd;

    case 4  % ---------------- Down (hanging) -------------
        phi = mod(al, 2*pi) - pi;            % deviation from pi
        Vc  = -P.K_dn*[th - r; thd; phi; ald];

    otherwise
        Vc = 0;
end

if abs(th) > P.th_safe && mode ~= 0
    tripped = 1;
end
if tripped > 0.5 || en < 0.5
    Vc = 0;
end

V    = min(max(Vc + uman, -P.Vmax), P.Vmax);
info = [mode; E; caught; tripped];
end
