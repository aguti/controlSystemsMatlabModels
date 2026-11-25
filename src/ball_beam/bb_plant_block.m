function sdot = bb_plant_block(s, V, Fd, P)
%BB_PLANT_BLOCK  Nonlinear ball and beam dynamics with DC motor and gearbox.
%   This file is the source code of the "Plant/Dynamics" block of the
%   Simulink model (bb_build_model copies it into the MATLAB Function block).
%   If you edit it, run bb_build_model again.
%
%   s  = [x; xd; alpha; alphad]
%   V  = motor voltage (already saturated by the amplifier) [V]
%   Fd = disturbance force on the ball, along the beam [N]
%
%   Equations (Lagrange; the ball rolls without slipping, so it spins at
%   xd/rb relative to the beam):
%     mb = m + Jb/rb^2 (= 7/5 m)
%     [ mb        -Jb/rb          ] [xdd]   [ m x ad^2 - m g sin(a) - bx xd + Fd + Fstop ]
%     [ -Jb/rb    J + Jb + m x^2  ] [add] = [ tau - Tf - 2 m x xd ad - m g x cos(a) + Tstop ]
%   Motor (inductance neglected), seen at the gearbox output:
%     tau = eta_g eta_m Kg kt (V - Kg km ad) / Rm = kv (V - Kg km ad)
%   Stops: stiff spring-dampers at the beam ends (ball) and at +-al_max (beam).
%#codegen
x = s(1); xd = s(2); al = s(3); ald = s(4);

tau = P.kv*(V - P.Kg*P.km*ald);
Tf  = P.Db*ald + P.Tc*tanh(ald/P.w_eps);
Fs  = stopForce(x,  xd,  P.x_max,  P.k_x,  P.c_x);
Ts  = stopForce(al, ald, P.al_max, P.k_al, P.c_al);

M   = [P.mb,          -P.Jb/P.rb;
       -P.Jb/P.rb,    P.J + P.Jb + P.m*x^2];
rhs = [P.m*x*ald^2 - P.m*P.g*sin(al) - P.bx*xd + Fd + Fs;
       tau - Tf + Ts - 2*P.m*x*xd*ald - P.m*P.g*x*cos(al)];
acc = M \ rhs;

sdot = [xd; acc(1); ald; acc(2)];
end

function F = stopForce(q, qd, qmax, k, c)
%STOPFORCE  One-sided contact force of a stop at +-qmax (never pulls).
F = 0;
if q > qmax
    F = min(0, -k*(q - qmax) - c*qd);
elseif q < -qmax
    F = max(0, -k*(q + qmax) - c*qd);
end
end
