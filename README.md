# Parameterized Synchronous FIFO UVM Verification

## Overview

As my first UVM project, this project verifies `sync_fifo_any_depth`, a synchronous FIFO with parameterized `DATA_WIDTH` and arbitrary positive `DEPTH`.

The verification environment includes:

- UVM sequence, sequencer, driver, monitor, agent, and environment
- Queue-based scoreboard reference model
- Functional coverage for FIFO boundary scenarios
- VCS/URG code coverage review
- Parameterized multi-seed regression
- Optional bound SystemVerilog Assertions (SVA)
- A dedicated runtime-reset test

## DUT Behavior
```text
| Scenario                          | Expected behavior                                    |
| `wr_en && !full`                  | Write is accepted                                    |
| `rd_en && !empty`                 | Read is accepted                                     |
| Empty + read                      | Read is rejected; FIFO remains empty                 |
| Full + write                      | Write is rejected; FIFO remains full                 |
| Empty + simultaneous read/write   | Only write is accepted                               |
| Full + simultaneous read/write    | Only read is accepted                                |
| Middle + simultaneous read/write  | Both operations are accepted; occupancy is unchanged |
| Reset                             | FIFO clears; `empty=1`, `full=0`, `dout=0`           |
```
## Verification Architecture

```text
sequence -> sequencer -> driver -> fifo_if -> DUT
                                           |
monitor -----------------------------------+
   |                                       |
   +--> scoreboard                          +--> functional coverage
```

The scoreboard is intentionally a simple behavioral model:

```text
accepted write -> model_queue.push_back(din)
accepted read  -> expected = model_queue.pop_front(); compare with dout
reset          -> model_queue.delete()
```

SVA is independent from the UVM class hierarchy and is attached to the DUT with `bind`.

## Existing Baseline Results

### Parameter regression

```text
DATA_WIDTH = {1, 8, 16}
DEPTH      = {1, 2, 3, 5, 10, 16, 17}
SEED       = {1, 101, 2026}

TOTAL : 63
PASS  : 63
FAIL  : 0
```

### Representative coverage (`DATA_WIDTH=8`, `DEPTH=10`)
```text
| Metric                  | Result  |
| Functional coverage     | 100.00% |
| DUT code coverage score | 96.46%  |
| Line coverage           | 94.12%  |
| Condition coverage      | 100.00% |
| Toggle coverage         | 98.86%  |
| Branch coverage         | 92.86%  |
```
The remaining uncovered code was manually reviewed as unreachable parameter-error logic or reset-related toggle accounting limitations.

## Project Layout

```text
rtl/  : FIFO RTL
 tb/  : UVM classes, interface, top testbench
sva/  : standalone assertion module and bind directive
sim/  : run script and file list
docs/ : verification plan
```

## Run Commands

Run from `sim/`.

```bash
./run.sh all 1       # default random smoke test
./run.sh regress     # 63-run parameter regression
./run.sh cov 1       # VCS code coverage and URG report
./run.sh sva 1       # bound-SVA smoke test
./run.sh reset 1     # runtime-reset directed test
./run.sh verdi       # open latest FSDB
```

One-off configuration:

```bash
FIFO_DATA_WIDTH=16 FIFO_DEPTH=17 ./run.sh all 2026
```

## Pass Criteria

A simulation passes only when:

```text
Scoreboard errors : 0
UVM_ERROR         : 0
UVM_FATAL         : 0
No FIFO_SVA assertion failure
No top-level FIFO assertion failure
```

## Scope Notes

- Bound SVA is exercised first by a dedicated smoke command rather than the full 63-run regression.
- Runtime reset is covered by a separate directed test.
- Code coverage is reviewed on representative configurations, not blindly merged across all parameter values.
- RAL, multi-agent virtual sequences, CDC verification, and formal verification are intentionally outside the scope of this single-clock FIFO project.
