function sdot = bp_plant_block(s, V, Fd, P)
%BP_PLANT_BLOCK  Nonlinear ball and plate dynamics with two DC motors.
%   This file is the source code of the "Plant/Dynamics" block of the
%   Simulink model (bp_build_model copies it into the MATLAB Function block).
%   If you edit it, run bp_build_model again.
%
%   s  = [x; xd; y; yd; alpha; alphad; beta; betad]
%   V  = [Va; Vb] motor voltages (already saturated by the amplifier) [V]
%   Fd = [Fx; Fy] disturbance force on the ball, in the plate plane [N]
%
%   Lagrange equations with q = [x; y; alpha; beta] and
%     T = 1/2 mb (xd^2 + yd^2) - (Jb/rb)(xd ad + yd bd)
%       + 1/2 (Ja + Jb + m x^2) ad^2 + 1/2 (Jbt + Jb + m y^2) bd^2 + m x y ad bd
%     U = m g (x sin(alpha) + y sin(beta))
%   give M(q) qdd = rhs(q, qd, V) with
%     M = [ mb      0       -Jb/rb          0
%           0       mb      0               -Jb/rb
%           -Jb/rb  0       Ja + Jb + m x^2 m x y
%           0       -Jb/rb  m x y           Jbt + Jb + m y^2 ]
%   Motors (inductance neglected), seen at the gearbox output:
%     tau = kv (V - Kg km w) - Db w - Tc tanh(w/w_eps)
%   Stops: stiff spring-dampers at the plate rim (ball) and at +-al_max (tilts).
%#codegen
x = s(1); xd = s(2); y = s(3); yd = s(4);
al = s(5); ald = s(6); be = s(7); bed = s(8);
m = P.m; g = P.g; c = P.Jb/P.rb;
V = [V(1); V(2)]; Fd = [Fd(1); Fd(2)];

ta = P.kv*(V(1) - P.Kg*P.km*ald) - P.Db*ald - P.Tc*tanh(ald/P.w_eps);
tb = P.kv*(V(2) - P.Kg*P.km*bed) - P.Db*bed - P.Tc*tanh(bed/P.w_eps);

M = [P.mb, 0,    -c,                    0;
     0,    P.mb, 0,                     -c;
     -c,   0,    P.Ja + P.Jb + m*x^2,   m*x*y;
     0,    -c,   m*x*y,                 P.Jbt + P.Jb + m*y^2];
rhs = [ -P.bx*xd + stopForce(x, xd, P.x_max, P.k_x, P.c_x) + Fd(1) ...
            + m*x*ald^2 + m*y*ald*bed - m*g*sin(al);
        -P.bx*yd + stopForce(y, yd, P.x_max, P.k_x, P.c_x) + Fd(2) ...
            + m*y*bed^2 + m*x*ald*bed - m*g*sin(be);
        ta + stopForce(al, ald, P.al_max, P.k_al, P.c_al) ...
            - 2*m*x*xd*ald - m*(xd*y + x*yd)*bed - m*g*x*cos(al);
        tb + stopForce(be, bed, P.al_max, P.k_al, P.c_al) ...
            - 2*m*y*yd*bed - m*(xd*y + x*yd)*ald - m*g*y*cos(be)];
acc = M \ rhs;

sdot = [xd; acc(1); yd; acc(2); ald; acc(3); bed; acc(4)];
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
