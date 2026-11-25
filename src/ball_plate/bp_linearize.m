function [A, B, C, D] = bp_linearize(P, J)
%BP_LINEARIZE  Single-axis linear model of the ball and plate at the origin.
%   [A, B, C, D] = bp_linearize(P, P.Ja)    x axis   (state [x; xd; alpha; alphad], input Va)
%   [A, B, C, D] = bp_linearize(P, P.Jbt)   y axis   (state [y; yd; beta;  betad],  input Vb)
%   Around x = y = 0 and level plate the two axes decouple exactly: every
%   coupling term (m x y, m x ad bd, ...) is of second order.
%   (Coulomb friction is neglected in the linearization.)

M      = [P.mb, -P.Jb/P.rb; -P.Jb/P.rb, J + P.Jb];
dR_dq  = [0, -P.m*P.g; -P.m*P.g, 0];
dR_dqd = [-P.bx, 0; 0, -P.beq];

Aq  = M\dR_dq;
Aqd = M\dR_dqd;
Bq  = M\[0; P.kv];

A = zeros(4); B = zeros(4,1);
A(1,2) = 1; A(3,4) = 1;
A([2 4],[1 3]) = Aq;
A([2 4],[2 4]) = Aqd;
B([2 4]) = Bq;
C = [1 0 0 0; 0 0 1 0];
D = [0; 0];
end
