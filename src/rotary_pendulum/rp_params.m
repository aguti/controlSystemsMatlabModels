function P = rp_params()
%RP_PARAMS  Parameters of the rotary (Furuta) pendulum.
%
%   Sign convention:
%     theta  arm angle [rad]        (+ counter-clockwise seen from above)
%     alpha  pendulum angle [rad]   (0 = UPRIGHT, pi = hanging)
%            alpha > 0  => the pendulum leans towards the +theta direction
%     V      motor voltage [V]      (V > 0 drives the arm towards +theta)
%
%   State: s = [theta; thetad; alpha; alphad]
%   Everything here can be changed from code with
%   rp.setParam('name', value) or by editing this file.
%   Default values are typical of a small desktop laboratory unit.

%% --- Rotary arm ---------------------------------------------------------
P.mr  = 0.095;            % arm mass [kg]
P.Lr  = 0.085;            % arm length, motor axis -> pendulum pivot [m]
P.Jh  = 6.0e-6;           % hub + motor rotor inertia [kg m^2]
P.Jr  = P.mr*P.Lr^2/3 + P.Jh;   % arm inertia about the motor axis [kg m^2]

%% --- Pendulum -----------------------------------------------------------
P.mp  = 0.024;            % pendulum mass [kg]
P.Lp  = 0.129;            % total pendulum length [m]
P.lp  = P.Lp/2;           % pivot -> centre of mass distance [m]
P.Jp  = P.mp*P.Lp^2/12;   % inertia about its CoM [kg m^2] (uniform rod)
P.g   = 9.81;             % gravity [m/s^2]

%% --- Derived inertias (recomputed by rp_design) -------------------------
P.J0  = P.Jr + P.mp*P.Lr^2;     % arm + pendulum mass at the tip
P.Ja  = P.Jp + P.mp*P.lp^2;     % pendulum about its pivot

%% --- Friction -----------------------------------------------------------
P.Dr    = 1.0e-4;         % arm viscous friction [N m s/rad]
P.Tc    = 5.0e-4;         % arm Coulomb friction [N m]
P.w_eps = 0.05;           % Coulomb smoothing (tanh) [rad/s]
P.Dp    = 5.0e-6;         % pendulum pivot viscous friction [N m s/rad]

%% --- DC motor and amplifier ---------------------------------------------
P.Rm   = 8.4;             % armature resistance [ohm]
P.kt   = 0.042;           % torque constant [N m/A]
P.km   = 0.042;           % back-EMF constant [V s/rad]
P.Vmax = 10;              % amplifier saturation [V]

%% --- Sensors (only angles are measured: theta and alpha) ----------------
P.res_th   = 2*pi/2048;   % arm encoder resolution [rad] (2048 counts/rev)
P.res_al   = 2*pi/2048;   % pendulum encoder resolution [rad]
P.noise_on = 0;           % 1 = add Gaussian noise to the measurements
P.noise_th = 1e-3;        % noise standard deviation on theta [rad]
P.noise_al = 1e-3;        % noise standard deviation on alpha [rad]

%% --- Timing -------------------------------------------------------------
P.Ts    = 0.002;          % controller / sensor sampling period [s] (500 Hz)
P.h     = 0.001;          % fixed solver step (ode4) [s]
P.tau_v = 0.005;          % derivative filter for velocity estimation [s]

%% --- Initial condition --------------------------------------------------
P.x0 = [0; 0; 0.1; 0];    % [theta; thetad; alpha; alphad]

%% --- Arm reference ------------------------------------------------------
P.th_ref_max = pi;        % reference saturation [rad]
P.ref_rate   = 2.0;       % reference rate limiter [rad/s]

%% --- LQR design (input: voltage) ----------------------------------------
P.Qup = diag([20 0.5 50 0.5]);    % pendulum up  (theta, thetad, alpha, alphad)
P.Rup = 1;
P.Qdn = diag([20 0.5 10 0.05]);   % pendulum down (positioning with sway damping)
P.Rdn = 1;
P.K_up = zeros(1,4);              % computed in rp_design
P.K_dn = zeros(1,4);

%% --- Energy-based swing-up (Astrom-Furuta) ------------------------------
P.k_E        = 200;       % energy gain
P.a_max      = 80;        % maximum arm acceleration during swing-up [rad/s^2]
P.kx_sw      = 25;        % arm re-centring during swing-up
P.kv_sw      = 1;
P.E_ref      = 0.2;       % target energy as a fraction of 2 mp g lp (keeps pumping
                          % until slightly above the upright energy; robustness)
P.al_catch   = 0.40;      % |alpha| to switch to LQR [rad] (~23 deg)
P.al_release = 0.9;       % |alpha| to fall back to swing-up [rad]

%% --- PID (pendulum angle) + PD (arm) ------------------------------------
P.Kp_al = 50;  P.Ki_al = 0;  P.Kd_al = 4;
P.Kp_th = 4;   P.Kd_th = 2;
P.I_max = 1;              % integrator anti-windup [rad s]

%% --- Safety -------------------------------------------------------------
P.th_safe = 2*pi;         % if |theta| > th_safe the control is cut off (cable wrap)
end
