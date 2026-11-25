function P = bb_derived(P)
%BB_DERIVED  Derived inertias and motor constants of the ball and beam.
P.Jb    = 2/5*P.m*P.rb^2;                              % ball about its centre
P.mb    = P.m + P.Jb/P.rb^2;                           % effective rolling mass (7/5 m)
P.J     = P.mbeam*P.L^2/12 + P.eta_g*P.Kg^2*P.Jm;      % beam + reflected rotor
P.x_max = P.L/2 - P.rb;                                % ball end stops
P.kv    = P.eta_g*P.eta_m*P.Kg*P.kt/P.Rm;              % torque per volt at stall [N m/V]
P.beq   = P.kv*P.Kg*P.km + P.Db;                       % back-EMF + viscous [N m s/rad]
end
