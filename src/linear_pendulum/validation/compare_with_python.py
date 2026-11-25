"""Compares the Simulink runs produced by run_validation.m against the
Python replica (python_reference_sim.py) under the same conditions.

Usage:  python3 compare_with_python.py [results_dir]   (default: ./results)
"""
import os, sys, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from python_reference_sim import *
R = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'results')
P=params(); A,B=linearize(P,0); P['K_up']=lqr(A,B,P['Qup'],P['Rup'])
A2,B2=linearize(P,np.pi); P['K_dn']=lqr(A2,B2,P['Qdn'],P['Rdn'])
rf=lambda t:0.3 if t>1 else 0.0; rc=lambda t:0.5 if t>1 else 0.0
Pn=dict(P); Kn=P['K_dn'].copy(); Kn[0,2:]=0; Pn['K_dn']=Kn
cases={'lqr_ic':(P,[0,0,.15,0],1,6,None,None),'lqr_step':(P,[0]*4,1,8,rf,None),
 'lqr_push':(P,[0]*4,1,6,None,lambda t:1.0 if 1<t<1.1 else 0),'swingup':(P,[0,0,np.pi,0],2,10,None,None),
 'pid_ic':(P,[0,0,.1,0],3,8,None,None),'pid_step':(P,[0]*4,3,10,rf,None),
 'crane':(P,[0,0,np.pi,0],4,8,rc,None),'crane_nosway':(Pn,[0,0,np.pi,0],4,8,rc,None)}
def settle(t,y,tol):
    i=np.where(np.abs(y)>tol)[0]; return t[i[-1]] if len(i) else 0
print(f"{'case':14s} {'RMS dx[mm]':>10s} {'max dx[mm]':>10s} {'RMS dth[deg]':>12s} {'max dth[deg]':>12s} | metric python vs simulink")
for name,(PP,x0,mode,T,ref,push) in cases.items():
    L=simulate(PP,x0,mode,T,ref=ref or (lambda t:0.0),push=push)
    tp,xp,thp=L[:,0],L[:,1],np.degrees(wrap(L[:,3]))
    M=np.loadtxt(f'{R}/{name}.csv',delimiter=',')
    ts,xs,ths=M[:,0],M[:,1],M[:,3]
    xi=np.interp(tp,ts,xs); ti=np.interp(tp,ts,np.unwrap(np.radians(ths))); thpu=np.unwrap(np.radians(thp))
    dth=np.degrees(np.angle(np.exp(1j*(ti-thpu))))
    dx=(xi-xp)*1000
    if name.startswith('crane'):
        m=f"residual sway t>5s: {np.abs(wrap(L[tp>5,3]-np.pi)).max()*57.3:.2f} vs {np.abs((M[ts>5,3]+360)%360-180).max():.2f} deg"
    elif name=='swingup':
        cp_=tp[np.argmax(L[:,6]>0)]; cs=ts[np.argmax(M[:,7]>0)]
        m=f"catch {cp_:.2f} vs {cs:.2f} s, max|x| {abs(xp).max():.3f} vs {abs(xs).max():.3f}"
    elif 'step' in name:
        m=f"x settle(2%) {settle(tp,xp-0.3,0.006):.2f} vs {settle(ts,xs-0.3,0.006):.2f} s, min x {xp.min()*1000:.1f} vs {xs.min()*1000:.1f} mm"
    else:
        m=f"th settle(0.5deg) {settle(tp,thp,0.5):.2f} vs {settle(ts,ths,0.5):.2f} s, Fmax {abs(L[:,5]).max():.1f} vs {abs(M[:,5]).max():.1f} N"
    print(f"{name:14s} {np.sqrt(np.mean(dx**2)):10.2f} {abs(dx).max():10.2f} {np.sqrt(np.mean(dth**2)):12.3f} {abs(dth).max():12.3f} | {m}")
print()
for name in ['lqr_step_ratelim','crane_ratelim']:
    M=np.loadtxt(f'{R}/{name}.csv',delimiter=','); ts,xs=M[:,0],M[:,1]; tgt=0.3 if 'lqr' in name else 0.5
    extra = f", residual sway t>5s {np.abs((M[ts>5,3]+360)%360-180).max():.2f} deg" if 'crane' in name else ''
    print(f"{name}: x settle(2%) {settle(ts,xs-tgt,0.02*tgt):.2f} s, min x {xs.min()*1000:.1f} mm, Fmax {abs(M[:,6]).max():.1f} N{extra}")
for f in ['0.1','0.2','0.5']:
    M=np.loadtxt(f'{R}/sine_{f}.csv',delimiter=','); ts,xs,rs=M[:,0],M[:,1],M[:,8]; k=ts>10
    w=2*np.pi*float(f); E=np.exp(-1j*w*ts[k])
    gx=np.sum(xs[k]*E); gr=np.sum(rs[k]*E)
    print(f"sine {f} Hz: gain {abs(gx/gr):.3f}, phase lag {np.degrees(np.angle(gr/gx)):.1f} deg, tripped={int(M[:,9].max())}")
M=np.loadtxt(f'{R}/lqr_ic_noise.csv',delimiter=','); ts=M[:,0]; k=ts>3
print(f"noise on: th std after 3 s {M[k,3].std():.3f} deg, F std {M[k,6].std():.2f} N, x std {M[k,1].std()*1000:.2f} mm")
