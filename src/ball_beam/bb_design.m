function [P, lin] = bb_design(P)
%BB_DESIGN  Recomputes the derived quantities and the LQR gain (with
%   integral action) and returns the linear model. Call it whenever masses,
%   lengths, friction, motor constants or Q/R weights change.
P = bb_derived(P);

[A, B, C, D] = bb_linearize(P);
Aa = [A, zeros(4,1); 1 0 0 0 0];          % augmented with z' = x - r
Ba = [B; 0];
P.K = bb_lqr(Aa, Ba, P.Q, P.R);
lin = struct('A',A,'B',B,'C',C,'D',D, 'Aa',Aa,'Ba',Ba, ...
             'poles_OL', eig(A), 'poles_CL', eig(Aa - Ba*P.K));
end
