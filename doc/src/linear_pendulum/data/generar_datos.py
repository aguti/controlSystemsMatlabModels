import numpy as np, json
from scipy import signal
from sim import *
D='./'  # ejecutar desde esta carpeta
P=params(); A,B=linearize(P,0); P['K_up']=lqr(A,B,P['Qup'],P['Rup'])
A2,B2=linearize(P,np.pi); P['K_dn']=lqr(A2,B2,P['Qdn'],P['Rdn'])
C=np.array([[1,0,0,0],[0,0,1,0]])
num={}
num['A_up']=A.tolist(); num['B_up']=B.ravel().tolist(); num['A_dn']=A2.tolist(); num['B_dn']=B2.ravel().tolist()
num['pol_up']=np.linalg.eigvals(A).tolist(); num['pol_dn']=np.linalg.eigvals(A2).tolist()
num['K_up']=P['K_up'].ravel().tolist(); num['K_dn']=P['K_dn'].ravel().tolist()
num['cl_up']=np.linalg.eigvals(A-B@P['K_up']).tolist(); num['cl_dn']=np.linalg.eigvals(A2-B2@P['K_dn']).tolist()
Cc=np.hstack([np.linalg.matrix_power(A,i)@B for i in range(4)]); num['rank_ctrb']=int(np.linalg.matrix_rank(Cc)); num['cond_ctrb']=float(np.linalg.cond(Cc))
O1=np.vstack([C[0:1]@np.linalg.matrix_power(A,i) for i in range(4)]); O2=np.vstack([C[1:2]@np.linalg.matrix_power(A,i) for i in range(4)])
num['rank_obs_x']=int(np.linalg.matrix_rank(O1)); num['rank_obs_th']=int(np.linalg.matrix_rank(O2))
for name,Ci in [('x',C[0:1]),('th',C[1:2])]:
    z,p,k=signal.ss2zpk(A,B,Ci,[[0]]); num['zeros_'+name]=np.real_if_close(z).tolist(); num['gain_'+name]=float(k)
    n,d=signal.ss2tf(A,B,Ci,[[0]]); num['tf_'+name]=[n.ravel().tolist(),d.ravel().tolist()]
num['wn_down']=float(np.sqrt(P['m']*P['g']*P['l']/(P['J']+P['m']*P['l']**2)))
pid=-np.array([[P['Kp_x'],P['Kd_x'],P['Kp_th'],P['Kd_th']]]); num['cl_pid']=np.linalg.eigvals(A-B@pid).tolist()
json.dump(num,open(D+'num.json','w'),default=lambda c:[c.real,c.imag],indent=1)

def save(name,L,dec=20,extra=None):
    L=L[::dec]
    th=np.degrees(wrap(L[:,3]))
    cols=[L[:,0],L[:,1],L[:,2],th,L[:,4],L[:,5],L[:,6]]
    hdr='t x xd thdeg thd F caught'
    if extra is not None: cols.append(extra[::dec]); hdr+=' r'
    np.savetxt(D+name+'.dat',np.column_stack(cols),header=hdr,comments='',fmt='%.5g')
save('lqr_ic',simulate(P,[0,0,0.15,0],1,6))
rf=lambda t:0.3 if t>1 else 0.0
L=simulate(P,[0,0,0,0],1,8,ref=rf); save('lqr_step',L,extra=np.array([rf(t) for t in L[:,0]]))
L=simulate(P,[0,0,0,0],1,6,push=lambda t:1.0 if 1<t<1.1 else 0); save('lqr_push',L)
L=simulate(P,[0,0,np.pi,0],2,10); save('swingup',L)
# energy for swingup
th=L[:,3]; thd=L[:,4]; E=0.5*(P['J']+P['m']*P['l']**2)*thd**2+P['m']*P['g']*P['l']*(np.cos(th)-1)
np.savetxt(D+'swingup_E.dat',np.column_stack([L[::20,0],E[::20]]),header='t E',comments='',fmt='%.5g')
print("swing caught", L[np.argmax(L[:,6]>0),0], abs(L[:,1]).max())
L=simulate(P,[0,0,0.1,0],3,8); save('pid_ic',L)
L=simulate(P,[0,0,0,0],3,10,ref=rf); save('pid_step',L,extra=np.array([rf(t) for t in L[:,0]]))
rc=lambda t:0.5 if t>1 else 0.0
L=simulate(P,[0,0,np.pi,0],4,8,ref=rc); save('crane',L,extra=np.array([rc(t) for t in L[:,0]]))
# crane without anti-sway: PD on cart only (K with zero angle gains)
Pn=dict(P); Kn=P['K_dn'].copy(); Kn[0,2:]=0; Pn['K_dn']=Kn
L=simulate(Pn,[0,0,np.pi,0],4,8,ref=rc); save('crane_nosway',L,extra=np.array([rc(t) for t in L[:,0]]))
# Q sweep
for q in [20,200,2000]:
    Pq=dict(P); Pq['Qup']=np.diag([50,1,q,1]); Pq['K_up']=lqr(A,B,Pq['Qup'],Pq['Rup'])
    save(f'qsweep_{q}',simulate(Pq,[0,0,0.15,0],1,5)); print('q',q,Pq['K_up'].round(1))
for R in [0.01,1.0]:
    Pq=dict(P); Pq['Rup']=R; Pq['K_up']=lqr(A,B,Pq['Qup'],R); save(f'rsweep_{R}',simulate(Pq,[0,0,0.15,0],1,5)); print('R',R,Pq['K_up'].round(1))
# robustness: M mismatch with nominal K
for M in [0.3,1.0,2.0]:
    Pm=dict(P); Pm['M']=M; save(f'msweep_{M}',simulate(Pm,[0,0,0.15,0],1,6))
# Bode of linear models
w=np.logspace(-1,2,300)
for name,(AA,BB) in [('up',(A,B)),('dn',(A2,B2))]:
    for oi,lab in [(0,'x'),(2,'th')]:
        Ci=np.zeros((1,4)); Ci[0,oi]=1
        _,H=signal.freqresp(signal.StateSpace(AA,BB,Ci,[[0]]),w)
        np.savetxt(D+f'bode_{name}_{lab}.dat',np.column_stack([w/(2*np.pi),20*np.log10(abs(H)),np.degrees(np.unwrap(np.angle(H)))]),header='f mag ph',comments='',fmt='%.5g')
# root locus-ish: LQR CL poles vs Qth
rows=[]
for q in np.logspace(0,4,40):
    K=lqr(A,B,np.diag([50,1,q,1]),0.1); ev=np.linalg.eigvals(A-B@K)
    for e in ev: rows.append([q,e.real,e.imag])
np.savetxt(D+'lqr_locus.dat',np.array(rows),header='q re im',comments='',fmt='%.5g')
# derivative filter: quantized theta, raw diff vs filtered
Ts=P['Ts']; t=np.arange(0,1,Ts); thr=0.2*np.sin(2*np.pi*1*t); thq=np.round(thr/P['res_th'])*P['res_th']
raw=np.r_[0,np.diff(thq)/Ts]; a=np.exp(-Ts/P['tau_v']); v=np.zeros_like(t)
for k in range(1,len(t)): v[k]=a*v[k-1]+(1-a)*(thq[k]-thq[k-1])/Ts
np.savetxt(D+'velest.dat',np.column_stack([t,0.2*2*np.pi*np.cos(2*np.pi*t),raw,v]),header='t true raw filt',comments='',fmt='%.5g')
print(json.dumps({k:num[k] for k in ['K_up','K_dn','pol_up','zeros_x','zeros_th','gain_x','wn_down','rank_obs_x','rank_obs_th','cond_ctrb']},default=lambda c:[round(c.real,3),round(c.imag,3)]))
