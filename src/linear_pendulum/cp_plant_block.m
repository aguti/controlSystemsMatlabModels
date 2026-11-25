function sdot = cp_plant_block(s, F, Fd, P)
%CP_PLANT_BLOCK  Nonlinear cart-pole dynamics.
%   This file is the source code of the "Plant/Dynamics" block of the
%   Simulink model (cp_build_model copies it into the MATLAB Function block).
%   If you edit it, run cp_build_model again.
%
%   s  = [x; xd; theta; thetad]   (theta = 0 up)
%   F  = actuator force on the cart [N]
%   Fd = horizontal disturbance force applied at the pendulum tip [N]
%
%   Equations (Lagrange, rod with inertia J):
%   (M+m) xdd + m l cos(th) thdd - m l sin(th) thd^2 = F + Fd - Ffric + Fwall
%   m l cos(th) xdd + (J + m l^2) thdd - m g l sin(th) = -bp thd + Fd Lp cos(th)
%#codegen
x = s(1); xd = s(2); th = s(3); thd = s(4);
c = cos(th); sn = sin(th);

Ffric = P.bc*xd + P.Fc*tanh(xd/P.v_eps);

Fw = 0;                                   % rail end stops
if x > P.x_lim
    Fw = -P.k_wall*(x - P.x_lim) - P.b_wall*xd;
elseif x < -P.x_lim
    Fw = -P.k_wall*(x + P.x_lim) - P.b_wall*xd;
end

Mt  = [P.M + P.m,   P.m*P.l*c;
       P.m*P.l*c,   P.J + P.m*P.l^2];
rhs = [F + Fd - Ffric + Fw + P.m*P.l*sn*thd^2;
       P.m*P.g*P.l*sn - P.bp*thd + Fd*P.Lp*c];
acc = Mt \ rhs;

sdot = [xd; acc(1); thd; acc(2)];
end
