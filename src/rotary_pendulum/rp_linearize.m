function [A, B, C, D] = rp_linearize(P, al0)
%RP_LINEARIZE  Linear model of the rotary pendulum around alpha = al0.
%   al0 = 0  -> inverted equilibrium (up)
%   al0 = pi -> hanging equilibrium (down)
%   State [theta; thetad; alpha; alphad], input V, measured outputs [theta; alpha].
%   The motor back-EMF appears as extra viscous damping on the arm.
%   (Coulomb friction is neglected in the linearization.)

c   = cos(al0);
hc  = P.mp*P.Lr*P.lp*c;
Mt  = [P.J0, hc; hc, P.Ja];
beq = P.Dr + P.kt*P.km/P.Rm;              % viscous + back-EMF
dR_dq  = [0 0; 0 P.mp*P.g*P.lp*c];        % d(rhs)/d[theta alpha]
dR_dqd = [-beq 0; 0 -P.Dp];               % d(rhs)/d[thetad alphad]

Aq  = Mt\dR_dq;
Aqd = Mt\dR_dqd;
Bq  = Mt\[P.kt/P.Rm; 0];

A = zeros(4); B = zeros(4,1);
A(1,2) = 1; A(3,4) = 1;
A([2 4],[1 3]) = Aq;
A([2 4],[2 4]) = Aqd;
B([2 4]) = Bq;
C = [1 0 0 0; 0 0 1 0];
D = [0; 0];
end
