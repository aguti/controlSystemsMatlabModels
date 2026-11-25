function [P, lin] = rp_design(P)
%RP_DESIGN  Recomputes the derived inertias, the LQR gains (up and down)
%   and returns the linear models. Call it whenever masses, lengths,
%   friction, motor constants or Q/R weights change.
P.lp = P.Lp/2;
P.Jp = P.mp*P.Lp^2/12;
P.Jr = P.mr*P.Lr^2/3 + P.Jh;
P.J0 = P.Jr + P.mp*P.Lr^2;
P.Ja = P.Jp + P.mp*P.lp^2;

[A, B, C, D] = rp_linearize(P, 0);
P.K_up = rp_lqr(A, B, P.Qup, P.Rup);
lin.up = struct('A',A,'B',B,'C',C,'D',D, ...
                'poles_OL', eig(A), 'poles_CL', eig(A - B*P.K_up));

[A2, B2, C2, D2] = rp_linearize(P, pi);
P.K_dn = rp_lqr(A2, B2, P.Qdn, P.Rdn);
lin.dn = struct('A',A2,'B',B2,'C',C2,'D',D2, ...
                'poles_OL', eig(A2), 'poles_CL', eig(A2 - B2*P.K_dn));
end
