function sdot = rp_plant_block(s, V, Fd, P)
%RP_PLANT_BLOCK  Nonlinear rotary (Furuta) pendulum dynamics with DC motor.
%   This file is the source code of the "Plant/Dynamics" block of the
%   Simulink model (rp_build_model copies it into the MATLAB Function block).
%   If you edit it, run rp_build_model again.
%
%   s  = [theta; thetad; alpha; alphad]   (alpha = 0 up)
%   V  = motor voltage (already saturated by the amplifier) [V]
%   Fd = disturbance force at the pendulum tip, tangent to the arm circle [N]
%
%   Equations (Lagrange; slender pendulum with inertia Jp about its CoM):
%     J0 = Jr + mp Lr^2,   Ja = Jp + mp lp^2
%   (J0 + Ja sin^2 a) thdd + mp Lr lp cos(a) add
%       = tau - Dr thd - Tc sgn(thd) - 2 Ja sin(a)cos(a) ad thd
%         + mp Lr lp sin(a) ad^2 + Fd Lr
%   mp Lr lp cos(a) thdd + Ja add
%       = Ja sin(a)cos(a) thd^2 + mp g lp sin(a) - Dp ad + Fd Lp cos(a)
%   Motor (inductance neglected): tau = kt (V - km thd) / Rm
%#codegen
thd = s(2); al = s(3); ald = s(4);
c = cos(al); sn = sin(al);

tau = P.kt*(V - P.km*thd)/P.Rm;
Tf  = P.Dr*thd + P.Tc*tanh(thd/P.w_eps);
hc  = P.mp*P.Lr*P.lp;

Mt  = [P.J0 + P.Ja*sn^2,  hc*c;
       hc*c,              P.Ja];
rhs = [tau - Tf - 2*P.Ja*sn*c*ald*thd + hc*sn*ald^2 + Fd*P.Lr;
       P.Ja*sn*c*thd^2 + P.mp*P.g*P.lp*sn - P.Dp*ald + Fd*P.Lp*c];
acc = Mt \ rhs;

sdot = [thd; acc(1); ald; acc(2)];
end
