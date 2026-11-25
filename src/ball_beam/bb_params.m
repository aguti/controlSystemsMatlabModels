function P = bb_params()
%BB_PARAMS  Parameters of the ball and beam.
%
%   Sign convention:
%     x      ball position along the beam [m]   (0 = pivot, + towards the right end)
%     alpha  beam angle [rad]                   (0 = horizontal)
%            alpha > 0  => the +x end goes UP, so the ball rolls towards -x
%     V      motor voltage [V]                  (V > 0 increases alpha)
%
%   State: s = [x; xd; alpha; alphad]
%   The beam is pivoted at its centre and driven directly by the output
%   shaft of a geared DC motor. Everything here can be changed from code
%   with bb.setParam('name', value) or by editing this file.
%   Default values are typical of a small desktop laboratory unit.

%% --- Ball (solid steel sphere) ------------------------------------------
P.m   = 0.067;            % ball mass [kg]
P.rb  = 0.0127;           % ball radius [m] (25.4 mm diameter)
P.bx  = 2e-3;             % rolling friction [N s/m]
P.g   = 9.81;             % gravity [m/s^2]

%% --- Beam ---------------------------------------------------------------
P.L     = 0.42;           % beam length [m]
P.mbeam = 0.35;           % beam mass [kg]

%% --- Beam friction (gearbox) --------------------------------------------
P.Db    = 1e-3;           % viscous friction [N m s/rad]
P.Tc    = 0.01;           % Coulomb friction [N m]
P.w_eps = 0.05;           % Coulomb smoothing (tanh) [rad/s]

%% --- DC motor, gearbox and amplifier ------------------------------------
P.Rm    = 2.6;            % armature resistance [ohm]
P.kt    = 0.00768;        % torque constant [N m/A]
P.km    = 0.00768;        % back-EMF constant [V s/rad]
P.Jm    = 3.9e-7;         % rotor inertia [kg m^2]
P.Kg    = 70;             % gear ratio
P.eta_g = 0.9;            % gearbox efficiency
P.eta_m = 0.69;           % motor efficiency
P.Vmax  = 10;             % amplifier saturation [V]

%% --- Mechanical stops ---------------------------------------------------
P.al_max = 0.35;          % beam angle stops [rad] (20 deg)
P.k_al   = 200;           % stop stiffness [N m/rad]
P.c_al   = 2;             % stop damping [N m s/rad]
P.k_x    = 2000;          % ball end-stop stiffness [N/m]
P.c_x    = 5;             % ball end-stop damping [N s/m]

%% --- Derived quantities (recomputed by bb_design) -----------------------
P = bb_derived(P);

%% --- Sensors ------------------------------------------------------------
P.res_al   = 2*pi/4096;   % beam encoder resolution [rad] (4096 counts/rev, output shaft)
P.res_x    = P.L/4096;    % ball position sensor: resistive track, 12-bit ADC [m]
P.noise_on = 0;           % 1 = add Gaussian noise to the measurements
P.noise_x  = 1e-3;        % noise standard deviation on x [m]
P.noise_al = 1e-3;        % noise standard deviation on alpha [rad]

%% --- Timing -------------------------------------------------------------
P.Ts    = 0.002;          % controller / sensor sampling period [s] (500 Hz)
P.h     = 0.001;          % fixed solver step (ode4) [s]
P.tau_v = 0.005;          % derivative filter, beam angular velocity [s]
P.tau_x = 0.02;           % derivative filter, ball velocity [s]

%% --- Initial condition --------------------------------------------------
P.x0 = [0.1; 0; 0; 0];    % [x; xd; alpha; alphad]

%% --- Ball reference -----------------------------------------------------
P.x_ref_max = 0.15;       % reference saturation [m]
P.ref_rate  = 0.3;        % reference rate limiter [m/s]

%% --- Beam angle loop (PD, inner loop) -----------------------------------
P.Kp_a = 40;              % [V/rad]
P.Kd_a = 1.5;             % [V s/rad]

%% --- Ball loop (PID, outer loop -> beam angle reference) ----------------
P.Kp_x = 1.3;             % [rad/m]
P.Kd_x = 0.8;             % [rad s/m]
P.Ki_x = 0.1;             % [rad/(m s)]
P.I_max      = 0.5;       % integrator clamp [m s]
P.e_int      = 0.02;      % integrate only when |x - r| < e_int [m] (anti-windup)
P.al_ref_max = 0.25;      % beam angle reference saturation [rad]
P.ff_on      = 1;         % 1 = compensate the ball weight torque on the beam

%% --- LQR with integral action (state [x-r, xd, alpha, alphad, int(x-r)])
P.Q = diag([1000 50 10 0.5 200]);
P.R = 1;
P.K = zeros(1,5);         % computed in bb_design
end
