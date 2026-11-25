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

## Quick start

Requires MATLAB + Simulink R2020b or later (tested on R2025b). The Control System Toolbox is optional.

```matlab
cd src/rotary_pendulum      % or src/linear_pendulum
rp_build_model              % cp_build_model for the linear pendulum; generates the .slx
rp_gui                      % cp_gui for the linear pendulum
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
| File prefix | Two letters per experiment (`cp_` cart-pole, `rp_` rotary pendulum) |
| Parameters | `<prefix>_params.m` defines the tunable struct `P`; `<prefix>_design.m` derives inertias and gains |
| Simulink blocks | `Reference → Controller → Actuator/Amplifier → Plant → Sensors`; the code of each MATLAB Function block lives in `<prefix>_*_block.m` |
| Timing | Fixed-step ode4, h = 1 ms; controller sampled at Ts = 2 ms |
| Angles | Pendulum angle 0 = upright, π = hanging; code in radians |
| Sensors | Only positions/angles are measured (quantized encoders, optional noise); velocities are estimated by the controller |
| Validation | `validation/run_validation.m` (MATLAB) + `validation/compare_with_python.py` |

## Adding a new experiment

1. Create `src/<experiment>/` with a new two-letter prefix, following the structure above (params, design, block files, `*_build_model`, class, GUI, `examples.m`, Python replica, `validation/`, README).
2. Create `doc/src/<experiment>/` with the LaTeX manual and a `data/` script that generates its figures from the Simulink model; copy the compiled PDF to `doc/<experiment>_manual.pdf`.
3. Add a row to the **Experiments** table above.
