function [A, B, C, D] = cp_linearize(P, th0)
%CP_LINEARIZE  Linear model of the cart-pole around theta = th0.
%   th0 = 0  -> inverted equilibrium (up)
%   th0 = pi -> hanging equilibrium (down)
%   State [x; xd; theta; thetad], input F, measured outputs [x; theta].
%   (Coulomb friction is neglected in the linearization.)

c  = cos(th0);
Mt = [P.M+P.m, P.m*P.l*c; P.m*P.l*c, P.J+P.m*P.l^2];
dR_dq  = [0 0; 0 P.m*P.g*P.l*c];     % d(rhs)/d[x theta]
dR_dqd = [-P.bc 0; 0 -P.bp];         % d(rhs)/d[xd thetad]

Aq  = Mt\dR_dq;
Aqd = Mt\dR_dqd;
Bq  = Mt\[1; 0];

A = zeros(4); B = zeros(4,1);
A(1,2) = 1; A(3,4) = 1;
A([2 4],[1 3]) = Aq;
A([2 4],[2 4]) = Aqd;
B([2 4]) = Bq;
C = [1 0 0 0; 0 0 1 0];
D = [0; 0];
end
