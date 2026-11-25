function [P, lin] = bp_design(P)
%BP_DESIGN  Recomputes the derived quantities and the per-axis LQR gains
%   (with integral action) and returns the linear models of both axes.
%   Call it whenever masses, sizes, friction, motor constants or Q/R change.
P = bp_derived(P);

[A, B, C, D] = bp_linearize(P, P.Ja);
Aa = [A, zeros(4,1); 1 0 0 0 0]; Ba = [B; 0];
P.Kx = bp_lqr(Aa, Ba, P.Q, P.R);
lin.x = struct('A',A,'B',B,'C',C,'D',D,'Aa',Aa,'Ba',Ba, ...
               'poles_OL', eig(A), 'poles_CL', eig(Aa - Ba*P.Kx));

[A, B, C, D] = bp_linearize(P, P.Jbt);
Aa = [A, zeros(4,1); 1 0 0 0 0]; Ba = [B; 0];
P.Ky = bp_lqr(Aa, Ba, P.Q, P.R);
lin.y = struct('A',A,'B',B,'C',C,'D',D,'Aa',Aa,'Ba',Ba, ...
               'poles_OL', eig(A), 'poles_CL', eig(Aa - Ba*P.Ky));
end
