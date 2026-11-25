"""Python mirror of the MATLAB/Simulink cart-pole model, used to validate
dynamics, LQR design and the controller modes before shipping the MATLAB code."""
import numpy as np
from scipy.linalg import solve_continuous_are

def params():
    P = dict(M=0.5, m=0.2, Lp=0.6, g=9.81, bc=0.5, Fc=0.2, bp=0.002,
             Fmax=15.0, tau_a=0.01, x_lim=0.8, k_wall=1e4, b_wall=50.0,
             Ts=0.002, h=0.001, tau_v=0.01, res_x=1e-4, res_th=2*np.pi/4096,
             Qup=np.diag([50, 1, 200, 1]), Rup=0.1,
             Qdn=np.diag([50, 1, 20, 1]), Rdn=0.1,
             k_E=5.0, a_max=3.0, kx_sw=8.0, kv_sw=1.0,
             th_catch=0.35, th_release=0.8,
             Kp_th=60.0, Ki_th=0.0, Kd_th=8.0, Kp_x=10.0, Kd_x=10.0,
             x_safe=0.7)
    P['l'] = P['Lp']/2
    P['J'] = P['m']*P['Lp']**2/12
    return P

def linearize(P, th0):
    M, m, l, J, g, bc, bp = P['M'], P['m'], P['l'], P['J'], P['g'], P['bc'], P['bp']
    c = np.cos(th0)
    Mt = np.array([[M+m, m*l*c], [m*l*c, J+m*l*l]])
    Mi = np.linalg.inv(Mt)
    # rhs = [F - bc xd ; m g l sin(th) - bp thd], d/dth sin = c
    dR_dq = np.array([[0, 0], [0, m*g*l*c]])          # wrt [x, th]
    dR_dqd = np.array([[-bc, 0], [0, -bp]])            # wrt [xd, thd]
    A = np.zeros((4, 4)); B = np.zeros((4, 1))
    A[0, 1] = 1; A[2, 3] = 1
    Aq = Mi @ dR_dq; Aqd = Mi @ dR_dqd; Bq = Mi @ np.array([[1], [0]])
    for i, r in enumerate([1, 3]):
        A[r, 0] = Aq[i, 0]; A[r, 2] = Aq[i, 1]
        A[r, 1] = Aqd[i, 0]; A[r, 3] = Aqd[i, 1]
        B[r, 0] = Bq[i, 0]
    return A, B

def lqr(A, B, Q, R):
    R = np.atleast_2d(R)
    X = solve_continuous_are(A, B, Q, R)
    return np.linalg.solve(R, B.T @ X)

def lqr_hamiltonian(A, B, Q, R):
    """Same algorithm as cp_lqr.m fallback (no toolbox)."""
    R = np.atleast_2d(R); n = A.shape[0]
    H = np.block([[A, -B @ np.linalg.solve(R, B.T)], [-Q, -A.T]])
    w, V = np.linalg.eig(H)
    Vs = V[:, w.real < 0]
    X = np.real(Vs[n:, :] @ np.linalg.inv(Vs[:n, :]))
    return np.linalg.solve(R, B.T @ X)

def plant(s, F, Fd, P):
    x, xd, th, thd = s
    M, m, l, J, g = P['M'], P['m'], P['l'], P['J'], P['g']
    c, sn = np.cos(th), np.sin(th)
    Ffric = P['bc']*xd + P['Fc']*np.tanh(xd/0.01)
    Fw = 0.0
    if x > P['x_lim']:  Fw = -P['k_wall']*(x-P['x_lim']) - P['b_wall']*xd
    if x < -P['x_lim']: Fw = -P['k_wall']*(x+P['x_lim']) - P['b_wall']*xd
    Mt = np.array([[M+m, m*l*c], [m*l*c, J+m*l*l]])
    rhs = np.array([F + Fd - Ffric + Fw + m*l*sn*thd**2,
                    m*g*l*sn - P['bp']*thd + Fd*P['Lp']*c])
    acc = np.linalg.solve(Mt, rhs)
    return np.array([xd, acc[0], thd, acc[1]])

def wrap(a):
    return (a + np.pi) % (2*np.pi) - np.pi

class Ctrl:
    def __init__(s, P):
        s.P = P; s.yp = None; s.v = np.zeros(2); s.I = 0.0; s.caught = 0
        s.a = np.exp(-P['Ts']/P['tau_v'])
    def __call__(s, y, r, mode, enable, uman):
        P = s.P
        if s.yp is None: s.yp = y.copy()
        s.v = s.a*s.v + (1-s.a)*(y - s.yp)/P['Ts']; s.yp = y.copy()
        x, th = y; xd, thd = s.v
        thw = wrap(th); E = 0.0; F = 0.0
        if mode == 0:
            F = 0.0
        elif mode == 1:     # LQR upright
            F = (-P["K_up"] @ np.array([x-r, xd, thw, thd])).item()
        elif mode == 2:     # swing-up + LQR
            if s.caught and abs(thw) > P['th_release']: s.caught = 0
            if (not s.caught) and abs(thw) < P['th_catch']: s.caught = 1
            if s.caught:
                F = (-P["K_up"] @ np.array([x-r, xd, thw, thd])).item()
            else:
                M, m, l, J, g = P['M'], P['m'], P['l'], P['J'], P['g']
                E = 0.5*(J+m*l*l)*thd**2 + m*g*l*(np.cos(th)-1)
                a = P['k_E']*E*thd*np.cos(th) - P['kx_sw']*(x-r) - P['kv_sw']*xd
                if abs(thd) < 0.05 and np.cos(th) < -0.99: a += 0.3*P['a_max']
                a = np.clip(a, -P['a_max'], P['a_max'])
                c, sn = np.cos(th), np.sin(th)
                thdd = (m*g*l*sn - m*l*c*a - P['bp']*thd)/(J+m*l*l)
                F = (M+m)*a + m*l*c*thdd - m*l*sn*thd**2 + P['bc']*xd
        elif mode == 3:     # PID angle + PD cart
            s.I += thw*P['Ts']; s.I = np.clip(s.I, -1, 1)
            F = (P['Kp_th']*thw + P['Ki_th']*s.I + P['Kd_th']*thd
                 + P['Kp_x']*(x-r) + P['Kd_x']*xd)
        elif mode == 4:     # crane (hanging) anti-sway
            phi = wrap(th - np.pi)
            F = (-P["K_dn"] @ np.array([x-r, xd, phi, thd])).item()
        if abs(x) > P['x_safe'] and mode in (1, 2, 3):
            pass
        F = enable*F + uman
        return float(np.clip(F, -P['Fmax'], P['Fmax'])), E

def simulate(P, x0, mode, T, ref=lambda t: 0.0, push=None):
    s = np.array(x0, float); Fa = 0.0; C = Ctrl(P)
    n = int(round(T/P['h'])); every = int(round(P['Ts']/P['h']))
    log = []; Fcmd = 0.0
    for k in range(n):
        t = k*P['h']
        if k % every == 0:
            y = np.array([np.round(s[0]/P['res_x'])*P['res_x'],
                          np.round(s[2]/P['res_th'])*P['res_th']])
            Fcmd, _ = C(y, ref(t), mode, 1.0, 0.0)
        Fd = push(t) if push else 0.0
        # RK4 on [state, actuator]
        def f(z):
            return np.concatenate([plant(z[:4], np.clip(z[4], -P['Fmax'], P['Fmax']), Fd, P),
                                   [(Fcmd - z[4])/P['tau_a']]])
        z = np.concatenate([s, [Fa]])
        k1 = f(z); k2 = f(z+P['h']/2*k1); k3 = f(z+P['h']/2*k2); k4 = f(z+P['h']*k3)
        z = z + P['h']/6*(k1+2*k2+2*k3+k4)
        s, Fa = z[:4], z[4]
        log.append([t, *s, Fcmd, C.caught])
    return np.array(log)
