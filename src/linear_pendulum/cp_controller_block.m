function [F, info] = cp_controller_block(y, r, cmd, P)
%CP_CONTROLLER_BLOCK  Discrete cart-pole controller (period P.Ts).
%   Source code of the "Controller/Control law" block. If you edit it,
%   run cp_build_model again.
%
%   Inputs
%     y   = [x_meas; theta_meas]  encoder measurements (positions only)
%     r   = cart position reference [m]
%     cmd = [mode; enable; u_manual]
%   Outputs
%     F    = force requested from the actuator [N]
%     info = [mode; energy; caught; safety_trip]
%
%   Modes
%     0  Open loop: F = u_manual (+ external signal u_ext)
%     1  LQR with the pendulum up (tracks r)
%     2  Energy-based swing-up + LQR catch
%     3  PID on the angle + PD on the cart (pendulum up)
%     4  Crane: pendulum down, positions the cart damping the sway
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

x = y(1); th = y(2); xd = v(1); thd = v(2);
thw = mod(th + pi, 2*pi) - pi;           % angle wrapped to [-pi, pi)

if mode ~= lastMode                       % reset on mode change
    I = 0; caught = 0; tripped = 0; lastMode = mode;
end
if en < 0.5
    tripped = 0;                          % disabling re-arms the safety latch
end

E = 0; Fc = 0;
switch mode
    case 1  % ---------------- LQR up --------------------
        Fc = -P.K_up*[x - r; xd; thw; thd];

    case 2  % ---------------- Swing-up + LQR ------------
        if caught > 0.5 && abs(thw) > P.th_release
            caught = 0;
        end
        if caught < 0.5 && abs(thw) < P.th_catch
            caught = 1;
        end
        if caught > 0.5
            Fc = -P.K_up*[x - r; xd; thw; thd];
        else
            Jp = P.J + P.m*P.l^2;
            E  = 0.5*Jp*thd^2 + P.m*P.g*P.l*(cos(th) - 1);   % E = 0 up at rest
            acc = P.k_E*E*thd*cos(th) - P.kx_sw*(x - r) - P.kv_sw*xd;
            if abs(thd) < 0.05 && cos(th) < -0.99            % kick-off from rest
                acc = acc + 0.3*P.a_max;
            end
            acc = min(max(acc, -P.a_max), P.a_max);
            % Force that produces the desired cart acceleration
            c = cos(th); sn = sin(th);
            thdd = (P.m*P.g*P.l*sn - P.m*P.l*c*acc - P.bp*thd)/Jp;
            Fc = (P.M + P.m)*acc + P.m*P.l*c*thdd - P.m*P.l*sn*thd^2 + P.bc*xd;
        end

    case 3  % ---------------- PID angle + PD cart -------
        I  = min(max(I + thw*P.Ts, -P.I_max), P.I_max);
        Fc = P.Kp_th*thw + P.Ki_th*I + P.Kd_th*thd ...
           + P.Kp_x*(x - r) + P.Kd_x*xd;

    case 4  % ---------------- Crane (down) --------------
        phi = mod(th, 2*pi) - pi;            % deviation from pi
        Fc  = -P.K_dn*[x - r; xd; phi; thd];

    otherwise
        Fc = 0;
end

if abs(x) > P.x_safe && mode ~= 0
    tripped = 1;
end
if tripped > 0.5 || en < 0.5
    Fc = 0;
end

F    = min(max(Fc + uman, -P.Fmax), P.Fmax);
info = [mode; E; caught; tripped];
end
