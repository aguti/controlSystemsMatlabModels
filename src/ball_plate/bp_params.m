function P = bp_params()
%BP_PARAMS  Parameters of the ball and plate.
%
%   Sign convention:
%     x, y   ball position on the plate [m]   (0 = centre of the plate)
%     alpha  plate tilt about the y axis [rad] (alpha > 0 raises the +x edge:
%            the ball rolls towards -x)
%     beta   plate tilt about the x axis [rad] (beta > 0 raises the +y edge:
%            the ball rolls towards -y)
%     Va, Vb motor voltages [V] (motor A drives alpha, motor B drives beta)
%
%   State: s = [x; xd; y; yd; alpha; alphad; beta; betad]
%   The plate is held by a two-axis gimbal at its centre; each axis is
%   driven directly by the output shaft of a geared DC motor. The ball is
%   seen by an overhead camera; the plate angles are measured by encoders.
%   Everything here can be changed from code with bp.setParam('name', value)
%   or by editing this file.

%% --- Ball (solid steel sphere) ------------------------------------------
P.m   = 0.067;            % ball mass [kg]
P.rb  = 0.0127;           % ball radius [m] (25.4 mm diameter)
P.bx  = 2e-3;             % rolling friction [N s/m]
P.g   = 9.81;             % gravity [m/s^2]

%% --- Plate and gimbal ---------------------------------------------------
P.a      = 0.15;          % half side of the square plate [m] (30 x 30 cm)
P.mplate = 0.45;          % plate mass [kg]
P.Jf     = 1.5e-3;        % inner gimbal frame inertia, carried by the alpha axis [kg m^2]

%% --- Gimbal friction (each axis, gearbox) -------------------------------
P.Db    = 1e-3;           % viscous friction [N m s/rad]
P.Tc    = 0.01;           % Coulomb friction [N m]
P.w_eps = 0.05;           % Coulomb smoothing (tanh) [rad/s]

%% --- DC motors, gearboxes and amplifier (two identical units) -----------
P.Rm    = 2.6;            % armature resistance [ohm]
P.kt    = 0.00768;        % torque constant [N m/A]
P.km    = 0.00768;        % back-EMF constant [V s/rad]
P.Jm    = 3.9e-7;         % rotor inertia [kg m^2]
P.Kg    = 70;             % gear ratio
P.eta_g = 0.9;            % gearbox efficiency
P.eta_m = 0.69;           % motor efficiency
P.Vmax  = 10;             % amplifier saturation [V]

%% --- Mechanical stops ---------------------------------------------------
P.al_max = 0.26;          % plate tilt stops, both axes [rad] (15 deg)
P.k_al   = 200;           % stop stiffness [N m/rad]
P.c_al   = 2;             % stop damping [N m s/rad]
P.k_x    = 2000;          % rim stiffness (ball against the plate edge) [N/m]
P.c_x    = 5;             % rim damping [N s/m]

%% --- Derived quantities (recomputed by bp_design) -----------------------
P = bp_derived(P);

%% --- Sensors ------------------------------------------------------------
P.res_al    = 2*pi/4096;  % plate encoders resolution [rad] (4096 counts/rev)
P.Tcam      = 0.02;       % camera frame period [s] (50 fps)
P.cam_delay = 1;          % camera latency [frames]
P.res_cam   = 5e-4;       % camera resolution on the plate [m/pixel] (600 px across)
P.noise_on  = 0;          % 1 = add Gaussian noise to the measurements
P.noise_cam = 5e-4;       % camera noise standard deviation [m]
P.noise_al  = 1e-3;       % encoder noise standard deviation [rad]

%% --- Timing -------------------------------------------------------------
P.Ts    = 0.002;          % controller / encoder sampling period [s] (500 Hz)
P.h     = 0.001;          % fixed solver step (ode4) [s]
P.tau_v = 0.005;          % derivative filter, plate angular velocities [s]
P.tau_c = 0.03;           % derivative filter, ball velocity (camera rate) [s]

%% --- Initial condition --------------------------------------------------
P.x0 = [0.08; 0; -0.05; 0; 0; 0; 0; 0];   % [x xd y yd alpha alphad beta betad]

%% --- Ball reference -----------------------------------------------------
P.x_ref_max = 0.10;       % reference saturation, each axis [m]
P.ref_rate  = 0.3;        % reference rate limiter, each axis [m/s]

%% --- Plate angle loops (PD, inner loops at Ts) --------------------------
P.Kp_a = 40;              % [V/rad]
P.Kd_a = 1.5;             % [V s/rad]

%% --- Ball loops (PID, outer loops at the camera rate) -------------------
P.Kp_x = 1.0;             % [rad/m]
P.Kd_x = 0.7;             % [rad s/m]
P.Ki_x = 0.1;             % [rad/(m s)]
P.I_max      = 0.5;       % integrator clamp [m s]
P.e_int      = 0.02;      % integrate only when |e| < e_int [m] (anti-windup)
P.al_ref_max = 0.2;       % plate angle reference saturation [rad]
P.ff_on      = 1;         % 1 = compensate the ball weight torque on the plate

%% --- LQR with integral action (per axis: [e, ed, angle, rate, int(e)]) ---
P.Q  = diag([500 60 10 0.5 100]);
P.R  = 1;
P.Kx = zeros(1,5);        % computed in bp_design (alpha axis, ball x)
P.Ky = zeros(1,5);        % computed in bp_design (beta axis, ball y)
end
