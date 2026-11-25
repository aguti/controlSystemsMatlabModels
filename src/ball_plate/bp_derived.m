function P = bp_derived(P)
%BP_DERIVED  Derived inertias and motor constants of the ball and plate.
P.Jb    = 2/5*P.m*P.rb^2;                     % ball about its centre
P.mb    = P.m + P.Jb/P.rb^2;                  % effective rolling mass (7/5 m)
Jplate  = P.mplate*(2*P.a)^2/12;              % plate about a centre line
Jrot    = P.eta_g*P.Kg^2*P.Jm;                % reflected rotor inertia
P.Ja    = Jplate + P.Jf + Jrot;               % alpha axis: plate + inner frame + rotor
P.Jbt   = Jplate + Jrot;                      % beta axis:  plate + rotor
P.x_max = P.a - P.rb;                         % ball against the rim
P.kv    = P.eta_g*P.eta_m*P.Kg*P.kt/P.Rm;     % torque per volt at stall [N m/V]
P.beq   = P.kv*P.Kg*P.km + P.Db;              % back-EMF + viscous [N m s/rad]
end
