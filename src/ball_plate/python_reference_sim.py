"""Python replica of the MATLAB/Simulink ball and plate model.

Used to design and cross-validate the dynamics, gains and controller modes
independently of Simulink (see validation/compare_with_python.py).
State: s = [x, x_dot, y, y_dot, alpha, alpha_dot, beta, beta_dot]
  x, y   ball position on the plate [m] (0 = centre)
  alpha  plate tilt about the y axis [rad] (alpha > 0 raises the +x edge)
  beta   plate tilt about the x axis [rad] (beta  > 0 raises the +y edge)
Inputs: motor voltages [Va, Vb] [V] (motor A tilts alpha, motor B tilts beta).
The ball position is measured by an overhead camera (frame rate Tcam,
latency of cam_delay frames); the plate angles by encoders.
"""
import numpy as np
from scipy.linalg import solve_continuous_are


def params():
    P = dict(
        # ball (solid steel sphere)
        m=0.067, rb=0.0127, bx=2e-3,
        # plate (square, gimbal at its centre)
        a=0.15, mplate=0.45, Jf=1.5e-3,
        g=9.81,
        # gimbal friction (each axis)
        Db=1e-3, Tc=0.01, w_eps=0.05,
        # DC motors + gearboxes + amplifier (two identical units)
        Rm=2.6, kt=0.00768, km=0.00768, Jm=3.9e-7, Kg=70.0, eta_g=0.9, eta_m=0.69,
        Vmax=10.0,
        # mechanical stops
        al_max=0.26, k_al=200.0, c_al=2.0,
        k_x=2000.0, c_x=5.0,
        # sensors / timing
        res_al=2*np.pi/4096,
        Tcam=0.02, cam_delay=1, res_cam=5e-4,
        Ts=0.002, h=0.001, tau_v=0.005, tau_c=0.03,
        # plate angle loops (PD)
        Kp_a=40.0, Kd_a=1.5,
        # ball loops (cascade PID -> plate angle references), run at the camera rate
        Kp_x=1.0, Kd_x=0.7, Ki_x=0.1, I_max=0.5, al_ref_max=0.2,
        e_int=0.02, ff_on=1,
        # LQR with integral action (per axis)
        Q=np.diag([500.0, 60.0, 10.0, 0.5, 100.0]), R=1.0,
    )
    return derived(P)


def derived(P):
    P['Jb'] = 2/5*P['m']*P['rb']**2
    P['mb'] = P['m'] + P['Jb']/P['rb']**2
    Jplate = P['mplate']*(2*P['a'])**2/12
    Jrot = P['eta_g']*P['Kg']**2*P['Jm']
    P['Ja'] = Jplate + P['Jf'] + Jrot          # alpha axis: plate + inner frame + rotor
    P['Jbt'] = Jplate + Jrot                   # beta axis: plate + rotor
    P['x_max'] = P['a'] - P['rb']
    P['kv'] = P['eta_g']*P['eta_m']*P['Kg']*P['kt']/P['Rm']
    P['beq'] = P['kv']*P['Kg']*P['km'] + P['Db']
    return P


def linearize(P, J):
    """Single-axis linear model [x, xd, alpha, alphad] (axes decouple at the origin)."""
    M = np.array([[P['mb'], -P['Jb']/P['rb']], [-P['Jb']/P['rb'], J + P['Jb']]])
    Mi = np.linalg.inv(M)
    dq = np.array([[0, -P['m']*P['g']], [-P['m']*P['g'], 0]])
    dqd = np.array([[-P['bx'], 0], [0, -P['beq']]])
    Aq, Aqd, Bq = Mi @ dq, Mi @ dqd, Mi @ np.array([[0], [P['kv']]])
    A = np.zeros((4, 4)); B = np.zeros((4, 1))
    A[0, 1] = 1; A[2, 3] = 1
    for i, r in enumerate([1, 3]):
        A[r, 0], A[r, 2] = Aq[i]
        A[r, 1], A[r, 3] = Aqd[i]
        B[r, 0] = Bq[i, 0]
    return A, B


def lqr(A, B, Q, R):
    R = np.atleast_2d(R)
    X = solve_continuous_are(A, B, Q, R)
    return np.linalg.solve(R, B.T @ X)


def design(P):
    for name, J in (('Kx', P['Ja']), ('Ky', P['Jbt'])):
        A, B = linearize(P, J)
        Aa = np.zeros((5, 5)); Aa[:4, :4] = A; Aa[4, 0] = 1
        P[name] = lqr(Aa, np.vstack([B, [[0]]]), P['Q'], P['R'])
    return P


def stop_force(q, qd, qmax, k, c):
    if q > qmax:
        return min(0.0, -k*(q - qmax) - c*qd)
    if q < -qmax:
        return max(0.0, -k*(q + qmax) - c*qd)
    return 0.0


def plant(s, V, Fd, P):
    x, xd, y, yd, al, ald, be, bed = s
    m, g, Jb, rb, mb = P['m'], P['g'], P['Jb'], P['rb'], P['mb']
    tq = [P['kv']*(V[i] - P['Kg']*P['km']*w) - P['Db']*w - P['Tc']*np.tanh(w/P['w_eps'])
          for i, w in enumerate((ald, bed))]
    c = Jb/rb
    M = np.array([[mb, 0, -c, 0],
                  [0, mb, 0, -c],
                  [-c, 0, P['Ja'] + Jb + m*x*x, m*x*y],
                  [0, -c, m*x*y, P['Jbt'] + Jb + m*y*y]])
    rhs = np.array([
        -P['bx']*xd + stop_force(x, xd, P['x_max'], P['k_x'], P['c_x']) + Fd[0]
        + m*x*ald**2 + m*y*ald*bed - m*g*np.sin(al),
        -P['bx']*yd + stop_force(y, yd, P['x_max'], P['k_x'], P['c_x']) + Fd[1]
        + m*y*bed**2 + m*x*ald*bed - m*g*np.sin(be),
        tq[0] + stop_force(al, ald, P['al_max'], P['k_al'], P['c_al'])
        - 2*m*x*xd*ald - m*(xd*y + x*yd)*bed - m*g*x*np.cos(al),
        tq[1] + stop_force(be, bed, P['al_max'], P['k_al'], P['c_al'])
        - 2*m*y*yd*bed - m*(xd*y + x*yd)*ald - m*g*y*np.cos(be)])
    acc = np.linalg.solve(M, rhs)
    return np.array([xd, acc[0], yd, acc[1], ald, acc[2], bed, acc[3]])


class Ctrl:
    def __init__(s, P):
        s.P = P; s.n = 0; s.Ncam = int(round(P['Tcam']/P['Ts']))
        s.pp = None; s.vb = np.zeros(2); s.ap = None; s.va = np.zeros(2)
        s.I = np.zeros(2); s.alr = np.zeros(2)
        s.aa = np.exp(-P['Ts']/P['tau_v']); s.ac = np.exp(-P['Tcam']/P['tau_c'])

    def __call__(s, ym, r, mode, uman=(0.0, 0.0), alman=(0.0, 0.0)):
        P = s.P
        p, ang = ym[:2], ym[2:]
        if s.pp is None: s.pp = p.copy(); s.ap = ang.copy()
        # plate angular velocities: every sample
        s.va = s.aa*s.va + (1 - s.aa)*(ang - s.ap)/P['Ts']; s.ap = ang.copy()
        new_frame = (s.n % s.Ncam) == 0
        s.n += 1
        if new_frame:                     # ball velocity: once per camera frame
            s.vb = s.ac*s.vb + (1 - s.ac)*(p - s.pp)/P['Tcam']; s.pp = p.copy()
        e = p - r
        V = np.zeros(2)
        if mode == 1:
            s.alr = np.array(alman, float)
            V = P['Kp_a']*(s.alr - ang) - P['Kd_a']*s.va
        elif mode == 2:
            if new_frame:
                for i in range(2):
                    if abs(e[i]) < P['e_int']:
                        s.I[i] = np.clip(s.I[i] + e[i]*P['Tcam'], -P['I_max'], P['I_max'])
                s.alr = np.clip(P['Kp_x']*e + P['Kd_x']*s.vb + P['Ki_x']*s.I,
                                -P['al_ref_max'], P['al_ref_max'])
            V = P['Kp_a']*(s.alr - ang) - P['Kd_a']*s.va + P['ff_on']*P['m']*P['g']*p/P['kv']
        elif mode == 3:
            if new_frame:
                for i in range(2):
                    if abs(e[i]) < P['e_int']:
                        s.I[i] = np.clip(s.I[i] + e[i]*P['Tcam'], -P['I_max'], P['I_max'])
            s.alr = np.zeros(2)
            for i, K in enumerate((P['Kx'], P['Ky'])):
                V[i] = (-K @ np.array([e[i], s.vb[i], ang[i], s.va[i], s.I[i]])).item()
            V = V + P['ff_on']*P['m']*P['g']*r/P['kv']
        return np.clip(V + np.array(uman), -P['Vmax'], P['Vmax'])


def simulate(P, x0, mode, T, ref=lambda t: np.zeros(2), push=None, alman=(0.0, 0.0)):
    s = np.array(x0, float); C = Ctrl(P)
    n = int(round(T/P['h'])); every = int(round(P['Ts']/P['h']))
    ecam = int(round(P['Tcam']/P['h']))
    q = lambda v, r: np.round(v/r)*r
    frames = [q(s[[0, 2]], P['res_cam'])]*(P['cam_delay'] + 1)
    log = []; Vc = np.zeros(2)
    for k in range(n):
        t = k*P['h']
        if k % ecam == 0:
            frames = frames[1:] + [q(s[[0, 2]], P['res_cam'])]
        if k % every == 0:
            ym = np.concatenate([frames[0], q(s[[4, 6]], P['res_al'])])
            Vc = C(ym, np.asarray(ref(t), float), mode, alman=alman)
        Fd = push(t) if push else (0.0, 0.0)
        f = lambda z: plant(z, Vc, Fd, P)
        k1 = f(s); k2 = f(s + P['h']/2*k1); k3 = f(s + P['h']/2*k2); k4 = f(s + P['h']*k3)
        s = s + P['h']/6*(k1 + 2*k2 + 2*k3 + k4)
        log.append([t, *s, *Vc, *C.alr])
    return np.array(log)
