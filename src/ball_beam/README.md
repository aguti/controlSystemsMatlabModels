# Ball and beam: Simulink simulation

Experiment 3 of the control systems series (after the [rotary pendulum](../rotary_pendulum/README.md); see the [list of experiments](../../README.md)).

A steel ball rolls in the groove of a 42 cm beam. The beam is pivoted at its centre and driven directly by the output shaft of a geared DC motor. The ball position is measured with a resistive track (12-bit ADC) and the beam angle with an encoder; the controller estimates both velocities with filtered derivatives. The input is the motor **voltage** (±10 V).

The theory/practice manual (in Spanish) is in [`doc/ball_beam_manual.pdf`](../../doc/ball_beam_manual.pdf), with its LaTeX sources in `doc/src/ball_beam/`.

## Requirements
- MATLAB + Simulink, R2020b or later (for `uifigure` and `tiledlayout`). Real-time simulation uses *pacing*, available since R2018a. Tested on R2025b.
- The Control System Toolbox is **optional**. Without it, `bb_lqr` solves the Riccati equation with the Hamiltonian method.

## Quick start
```matlab
cd src/ball_beam
bb_build_model      % generates ballbeam_sim.slx (first time only, or after editing the *_block.m files)
bb_gui              % live visual interface with 3D animation
% or, from code:
bb = BallBeam(); bb.setMode('lqr'); bb.setInitialState([0.1 0 0 0]);
res = bb.run(5); bb_plot_results(res); bb.animate(res);
```
`examples.m` contains a section-by-section walkthrough: LQR, LQR vs cascade, weight feedforward, tap rejection, open-loop instability, sine tracking, inner loop, ball-mass robustness and live control from code.

## Conventions
| Variable | Meaning |
|---|---|
| `x` | Ball position along the beam [m]; 0 = pivot, + towards the right end. End stops at ±(L/2 − rb) = ±19.7 cm |
| `α` | Beam angle [rad]; 0 = horizontal. **α > 0 raises the +x end**, so the ball rolls towards −x. Stops at ±20° |
| `V` | Motor voltage [V]; ±10 V saturation. `V > 0` increases `α` |
| State | `[x; ẋ; α; α̇]` |

The code interface works in **metres and radians**; the GUI and the `*_cm`/`*_deg` fields of the results use centimetres and degrees.

## Structure of the `ballbeam_sim.slx` model
```
Clock, cmd_ref, ref_ext → [Reference] → r ─┐
cmd_ctrl ──────────────────────────────────┼→ [Controller] → (+u_ext) → [Amplifier] → [Plant] → s
                    y_meas ← [Sensors] ←───┘                    cmd_dist + d_ext ┘          │
                                ↑───────────────────────────────────────────────────────────┘
s, y_meas, V, r, info → telemetry → out.tel (12 signals) + Scope
```
- **Plant**: full nonlinear ball-and-beam dynamics (Lagrange; the ball rolls without slipping and its spin inertia is kept, so it behaves as a 7/5 m mass) coupled to the beam, which carries the beam, the reflected rotor inertia and the ball. Centrifugal (`m x α̇²`) and Coriolis (`2 m x ẋ α̇`) terms, the ball weight torque on the beam, a DC motor with back-EMF through a 70:1 gearbox, viscous + Coulomb friction on the beam and rolling friction on the ball. Stiff one-sided stops at both beam ends and at ±20° of beam tilt.
- **Amplifier**: ±10 V saturation.
- **Sensors**: ball position quantized to L/4096 (0.10 mm), beam encoder with 4096 counts/rev on the output shaft, optional noise, 500 Hz sampling.
- **Controller**: discrete, `Ts` = 2 ms, 4 modes.
- **Solver**: fixed-step ode4, h = 1 ms.

The code of each *MATLAB Function* block lives in `bb_plant_block.m`, `bb_controller_block.m` and `bb_ref_block.m`. If you edit any of them, run `bb_build_model` again.

## Control modes
| # | Mode | Description |
|---|---|---|
| 0 | `open` | Applies `V = u_manual + u_ext`. Useful for identification |
| 1 | `beam` | PD servo of the beam angle to `α_manual`; the ball is free (shows the open-loop instability) |
| 2 | `cascade` | Outer PID on the ball position (output = beam angle reference, ±14°) → inner PD on the beam angle |
| 3 | `lqr` | LQR with integral action on the ball position, state `[x−r, ẋ, α, α̇, ∫(x−r)]` |

Both ball controllers compensate the ball **weight torque** on the beam (`ff_on = 1`): the cascade adds `m g x / kv`, the LQR the equilibrium voltage `m g r / kv`. Integral action only runs when the ball is within 2 cm of the reference (conditional-integration anti-windup).

## Code interface (`BallBeam`)
| Method | What it does |
|---|---|
| `run(T)` | Batch simulation; returns a struct with `t, x, xd, al, ald, xm, alm, Vcmd, Vact, r, mode, alr, I` plus `x_cm, r_cm, al_deg, alr_deg` |
| `start()` / `stop()` / `pause()` / `resume()` | Live execution at `PacingRate` speed (1 = real time) |
| `setMode`, `enable`, `setVoltage`, `setBeamAngle`, `setRef(type, offset, amp, f)`, `push(F, dur)` | Work **live** |
| `setParam(name, value)` / `setParams(struct)` | Change parameters, recompute inertias and the LQR and apply them, also live |
| `setParamRaw(name, value)` | Changes a parameter without recomputing gains (robustness tests) |
| `setRefSignal(t, r)`, `setVoltageSignal(t, u)`, `setDisturbanceSignal(t, Fd)` | Load time signals; read when the simulation starts |
| `addTelemetryCallback(@(t, d) ...)` | Calls your function with live telemetry at up to `TelemetryRate` Hz |

## GUI (`bb_gui`)
- 3D animation of the ball and beam (base, pedestal, geared motor, beam with a centimetre scale and end stops, two-tone rolling ball, shadow, green reference marker) and live plots of x/r, α/α_ref and V. The view can be rotated with the mouse or chosen from the **View** list (3D, front, top, side).
- Controls for: mode, control enable, weight feedforward, manual voltage, beam angle (mode `beam`), tap on the ball, ball reference (constant, sine, square, triangle or external, in cm), cascade PID gains and LQR Q/R weights with hot recomputation, sensor noise, simulation speed and initial state.
- Keyboard: ←/→ tap the ball towards −x/+x; ↑/↓ change the beam angle by ±1° in mode `beam`.
- **Export** stores the last run in `bb_res` in the workspace and plots it.

## Validation
`validation/run_validation.m` runs the reference scenarios on the Simulink model and `validation/compare_with_python.py` compares them sample by sample with the Python replica (`python_reference_sim.py`). Under matched conditions (reference rate limiter off) the discrepancies are ≤0.32 mm RMS in `x` and ≤0.03° RMS in `α` (see appendix B of the manual).
```matlab
cd src/ball_beam/validation
run_validation                     % writes results/*.csv
!python3 compare_with_python.py
```

## Expected behaviour
Verified in Simulink (R2025b) and against the Python replica:
- **LQR from x₀ = 10 cm**: within 5 mm of the centre in 0.68 s. K = [−43.5 −15.7 18.8 1.18 −14.1].
- **10 cm reference step**: LQR settles within 5 mm in 0.64 s (2.5 % overshoot); the cascade PID in 1.50 s (0.8 %). With the default 0.3 m/s reference rate limiter: 0.85 s and 1.67 s.
- **Weight feedforward**: without it (and without integral action) the cascade stops about 1 cm past a 10 cm reference.
- **Tap** (0.2 N × 50 ms): the ball is displaced < 2 cm and is back within 2 mm in 1.2 s (cascade) to 2.2 s (LQR).
- **Open-loop instability**: with the beam held at −2° the ball reaches the end stop in 1.25 s.
- **Sine tracking (±10 cm)**: LQR gain 0.96 and 36° lag at 0.25 Hz; cascade 0.83 and 51°.
