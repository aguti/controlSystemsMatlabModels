# Control Systems MATLAB Models

A growing series of control-systems laboratory experiments, simulated in MATLAB/Simulink. Each experiment comes with:

- a **script-generated Simulink model** with nonlinear plant, actuator, sensors and a discrete multi-mode controller;
- a **code interface** (a MATLAB class) for batch runs and live, real-time control;
- a **live GUI** with an animation of the system and real-time plots;
- a **theory/practice manual** (in Spanish) with modelling, analysis, controller design and guided lab exercises;
- a **cross-validation** of the Simulink model against an independent Python replica.

## Experiments

| # | Experiment | Code | Manual | Inputs → measurements | Control modes |
|---|---|---|---|---|---|
| 1 | Linear pendulum (cart-pole) | [`src/linear_pendulum`](src/linear_pendulum/README.md) | [PDF](doc/linear_pendulum_manual.pdf) | Force on the cart → cart position `x`, pendulum angle `θ` | open, LQR, swing-up, PID, crane |
| 2 | Rotary pendulum (Furuta) | [`src/rotary_pendulum`](src/rotary_pendulum/README.md) | [PDF](doc/rotary_pendulum_manual.pdf) | Motor voltage → arm angle `θ`, pendulum angle `α` | open, LQR, swing-up, PID, down (anti-sway) |
| 3 | Ball and beam | [`src/ball_beam`](src/ball_beam/README.md) | [PDF](doc/ball_beam_manual.pdf) | Motor voltage → ball position `x`, beam angle `α` | open, beam servo, cascade PID, LQR + integral |
| 4 | Ball and plate | [`src/ball_plate`](src/ball_plate/README.md) | [PDF](doc/ball_plate_manual.pdf) | Two motor voltages → ball position `(x, y)` (camera), plate tilts `α`, `β` | open, plate servo, cascade PID, LQR + integral (per axis) |

## Quick start

Requires MATLAB + Simulink R2020b or later (tested on R2025b). The Control System Toolbox is optional.

```matlab
cd src/rotary_pendulum      % or src/linear_pendulum, src/ball_beam, src/ball_plate
rp_build_model              % cp_/bb_/bp_build_model for the others; generates the .slx
rp_gui                      % cp_gui, bb_gui, bp_gui
```

Each experiment's README describes its model, code interface, GUI, validation and expected results. `examples.m` in each folder is a section-by-section walkthrough.

## Repository layout

```
src/<experiment>/            MATLAB code, Python replica and validation/ scripts
doc/<experiment>_manual.pdf  compiled manuals
doc/src/<experiment>/        LaTeX sources of each manual (data/ holds the scripts that generate its figures)
admin/conversations/         exported development conversations
```

The generated Simulink models (`*_sim.slx`), Simulink caches and validation results are not versioned: run the experiment's `*_build_model` and `validation/run_validation` to regenerate them.

## Common conventions

All experiments follow the same structure so that what is learnt in one carries over to the next:

| Item | Convention |
|---|---|
| File prefix | Two letters per experiment (`cp_` cart-pole, `rp_` rotary pendulum, `bb_` ball and beam, `bp_` ball and plate) |
| Parameters | `<prefix>_params.m` defines the tunable struct `P`; `<prefix>_design.m` derives inertias and gains |
| Simulink blocks | `Reference → Controller → Actuator/Amplifier → Plant → Sensors`; the code of each MATLAB Function block lives in `<prefix>_*_block.m` |
| Timing | Fixed-step ode4, h = 1 ms; controller sampled at Ts = 2 ms |
| Angles | Pendulum angle 0 = upright, π = hanging; beam/plate tilt 0 = level, positive raises the + end; code in radians and metres |
| Sensors | Only positions/angles are measured (quantized encoders, resistive track or camera, optional noise); velocities are estimated by the controller |
| Validation | `validation/run_validation.m` (MATLAB) + `validation/compare_with_python.py` |

## Adding a new experiment

1. Create `src/<experiment>/` with a new two-letter prefix, following the structure above (params, design, block files, `*_build_model`, class, GUI, `examples.m`, Python replica, `validation/`, README).
2. Create `doc/src/<experiment>/` with the LaTeX manual and a `data/` script that generates its figures from the Simulink model; copy the compiled PDF to `doc/<experiment>_manual.pdf`.
3. Add a row to the **Experiments** table above.
