function P = cp_params()
%CP_PARAMS  Parameters of the linear pendulum (cart-pole).
%
%   Sign convention:
%     x      cart position [m]             (+ to the right)
%     theta  pendulum angle [rad]          (0 = UPRIGHT, pi = hanging)
%            theta > 0  => the pendulum leans towards +x
%     F      horizontal force on the cart [N]  (+ to the right)
%
%   State: s = [x; xd; theta; thetad]
%   Everything here can be changed from code with
%   cp.setParam('name', value) or by editing this file.

%% --- Mechanics ----------------------------------------------------------
P.M   = 0.5;              % cart mass [kg]
P.m   = 0.2;              % rod mass [kg]
P.Lp  = 0.6;              % total rod length [m]
P.l   = P.Lp/2;           % pivot -> centre of mass distance [m]
P.J   = P.m*P.Lp^2/12;    % inertia about the CoM [kg m^2] (uniform rod)
P.g   = 9.81;             % gravity [m/s^2]

P.bc    = 0.5;            % cart viscous friction [N s/m]
P.Fc    = 0.2;            % cart Coulomb friction [N]
P.v_eps = 0.01;           % Coulomb smoothing (tanh) [m/s]
P.bp    = 0.002;          % pivot viscous friction [N m s/rad]

%% --- Rail (physical end stops) ------------------------------------------
P.x_lim  = 0.8;           % usable rail half-length [m]  (1.6 m rail)
P.k_wall = 1e4;           % end-stop stiffness [N/m]
P.b_wall = 50;            % end-stop damping [N s/m]

%% --- Linear actuator ----------------------------------------------------
P.Fmax  = 15;             % force saturation [N]
P.tau_a = 0.01;           % actuator time constant [s]

%% --- Sensors (only positions are measured: x and theta) -----------------
P.res_x    = 1e-4;        % linear encoder resolution [m]
P.res_th   = 2*pi/4096;   % angular encoder resolution [rad] (4096 counts/rev)
P.noise_on = 0;           % 1 = add Gaussian noise to the measurements
P.noise_x  = 1e-4;        % noise standard deviation on x [m]
P.noise_th = 1e-3;        % noise standard deviation on theta [rad]

%% --- Timing -------------------------------------------------------------
P.Ts    = 0.002;          % controller / sensor sampling period [s] (500 Hz)
P.h     = 0.001;          % fixed solver step (ode4) [s]
P.tau_v = 0.01;           % derivative filter for velocity estimation [s]

%% --- Initial condition --------------------------------------------------
P.x0 = [0; 0; 0.1; 0];    % [x; xd; theta; thetad]

%% --- Cart reference -----------------------------------------------------
P.x_ref_max = 0.6;        % reference saturation [m]
P.ref_rate  = 1.0;        % reference rate limiter [m/s]

%% --- LQR design ---------------------------------------------------------
P.Qup = diag([50 1 200 1]);   % pendulum up  (x, xd, theta, thetad)
P.Rup = 0.1;
P.Qdn = diag([50 1 20 1]);    % pendulum down (crane mode)
P.Rdn = 0.1;
P.K_up = zeros(1,4);          % computed in cp_design
P.K_dn = zeros(1,4);

%% --- Energy-based swing-up (Astrom-Furuta) ------------------------------
P.k_E        = 5;         % energy gain
P.a_max      = 3;         % maximum cart acceleration during swing-up [m/s^2]
P.kx_sw      = 8;         % cart re-centring during swing-up
P.kv_sw      = 1;
P.th_catch   = 0.35;      % |theta| to switch to LQR [rad] (~20 deg)
P.th_release = 0.8;       % |theta| to fall back to swing-up [rad]

%% --- PID (angle) + PD (cart) --------------------------------------------
P.Kp_th = 60;  P.Ki_th = 0;  P.Kd_th = 8;
P.Kp_x  = 10;  P.Kd_x  = 10;
P.I_max = 1;              % integrator anti-windup [rad s]

%% --- Safety -------------------------------------------------------------
P.x_safe = 0.78;          % if |x| > x_safe the control is cut off (latched)
end
