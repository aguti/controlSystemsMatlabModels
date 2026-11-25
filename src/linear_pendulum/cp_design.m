function [P, lin] = cp_design(P)
%CP_DESIGN  Computes the LQR gains (up and down) and returns the linear
%   models. Call it whenever masses, lengths, friction or Q/R weights change.
[A, B, C, D] = cp_linearize(P, 0);
P.K_up = cp_lqr(A, B, P.Qup, P.Rup);
lin.up = struct('A',A,'B',B,'C',C,'D',D, ...
                'poles_OL', eig(A), 'poles_CL', eig(A - B*P.K_up));

[A2, B2, C2, D2] = cp_linearize(P, pi);
P.K_dn = cp_lqr(A2, B2, P.Qdn, P.Rdn);
lin.dn = struct('A',A2,'B',B2,'C',C2,'D',D2, ...
                'poles_OL', eig(A2), 'poles_CL', eig(A2 - B2*P.K_dn));
end
