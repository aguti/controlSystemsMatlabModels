function [A, B, C, D] = bb_linearize(P)
%BB_LINEARIZE  Linear model of the ball and beam around x = 0, alpha = 0.
%   State [x; xd; alpha; alphad], input V, measured outputs [x; alpha].
%   The motor back-EMF appears as viscous damping on the beam (beq) and the
%   ball weight as a torque -m g x on the beam.
%   (Coulomb friction is neglected in the linearization.)

M      = [P.mb, -P.Jb/P.rb; -P.Jb/P.rb, P.J + P.Jb];
dR_dq  = [0, -P.m*P.g; -P.m*P.g, 0];      % d(rhs)/d[x alpha]
dR_dqd = [-P.bx, 0; 0, -P.beq];           % d(rhs)/d[xd alphad]

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
