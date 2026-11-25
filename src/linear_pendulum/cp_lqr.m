function K = cp_lqr(A, B, Q, R)
%CP_LQR  LQR gain. Uses lqr() if the Control System Toolbox is available;
%   otherwise solves the Riccati equation with the Hamiltonian method.
try
    K = lqr(A, B, Q, R);
    return
catch
end
n  = size(A,1);
H  = [A, -B/R*B'; -Q, -A'];
[V, Dg] = eig(H);
ev = diag(Dg);
Vs = V(:, real(ev) < 0);             % stable subspace (n vectors)
X  = real(Vs(n+1:end,:) / Vs(1:n,:));
K  = R \ (B'*X);
end
