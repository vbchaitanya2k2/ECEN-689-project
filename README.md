# DifuzzRTL with Power Scheduling and Smart Eviction

This is a fork of [DifuzzRTL](https://github.com/compsec-snu/difuzz-rtl)
(IEEE S&P '21) with a small change to the parent-selection policy in
the mutator. The change adds AFL-style power scheduling and a smart
eviction policy. At a 9-hour wall-clock budget we observe **+5.07%
coverage on Rocket and +5.23% on BOOM v1.3**, geomean across all
available runs, at no measurable runtime cost.

Course: ECEN 689 (Spring 2026), Texas A&M University.
Team: Team-Assert3.

## What changed

The artifact's `Fuzzer/src/mutator.py` picks parents with
`random.choice(self.corpus)`. We replace that with a weighted pick
behind a single environment variable, `DIFUZZ_SCHED`. Four variants
are available:

| `DIFUZZ_SCHED` | Picks parent by         | Eviction          |
| -------------- | ----------------------- | ----------------- |
| `baseline`     | uniform `random.choice` | FIFO              |
| `pow`          | total reward count      | FIFO              |
| `powrate`      | smoothed success rate   | FIFO              |
| `evict`        | smoothed success rate   | smart (drop duds) |

`NO_GUIDE=1` (the artifact's existing flag) gives a no-guidance random
floor for reference.

The total change is approximately 30 lines, almost entirely in
`Fuzzer/src/mutator.py`. `Fuzzer/src/mutator_old.py` is the upstream
artifact's mutator, kept as a reference.

## Build

Follow the upstream DifuzzRTL setup. On a Linux server with a
RISC-V toolchain, Verilator, and Spike already installed:

```
bash scripts/setup_linux_server.sh    # builds spike/elf2hex if missing
. scripts/env.local.sh                # sets PATH, PYTHONPATH, SPIKE
```

If your cluster doesn't have the toolchain, see
[`PORTABLE_SERVER.md`](PORTABLE_SERVER.md).

## First-time warm-up (build the Verilator models)

The fuzzer needs a compiled Verilator model of each core before it can
run. The first invocation builds it; subsequent runs reuse the
artefact. Do this once per core after a fresh clone:

```
. scripts/env.local.sh
mkdir -p server_runs/rocket-15k server_runs/boom13-7k
cd Fuzzer

# build the Rocket model (~15-20 min)
make SIM_BUILD=../server_runs/rocket-15k/build-rocket \
     VFILE=RocketTile_state TOPLEVEL=RocketTile \
     NUM_ITER=10 OUT=../server_runs/rocket-15k/_warmup RECORD=1

# build the BOOM model (~15-20 min)
make SIM_BUILD=../server_runs/boom13-7k/build-boom13 \
     VFILE=SmallBoomTile_v1.3_state TOPLEVEL=BoomTile \
     NUM_ITER=10 OUT=../server_runs/boom13-7k/_warmup RECORD=1

rm -rf ../server_runs/rocket-15k/_warmup ../server_runs/boom13-7k/_warmup
cd ..
```

The build dirs `server_runs/rocket-15k/build-rocket` and
`server_runs/boom13-7k/build-boom13` are reused by the sweep script
below, so you only have to do this once.

## Run a single configuration

```
. scripts/env.local.sh
mkdir -p server_runs/demo                # create output dir if not present
export DIFUZZ_SCHED=evict                # or pow, powrate, baseline
cd Fuzzer
make SIM_BUILD=../server_runs/rocket-15k/build-rocket \
     VFILE=RocketTile_state TOPLEVEL=RocketTile \
     NUM_ITER=200 OUT=../server_runs/demo/out RECORD=1
```

The console will print `[DifuzzRTL] DIFUZZ_SCHED = evict` at startup.
Output is written to `server_runs/demo/out/cov_log_*.txt` with one row
per coverage event:

```
<elapsed_seconds>  <iteration>  <coverage>
```

For BOOM, swap the make arguments:

```
SIM_BUILD=../server_runs/demo/build-boom
VFILE=SmallBoomTile_v1.3_state
TOPLEVEL=BoomTile
NUM_ITER=7000
```

For a no-guidance reference run, also pass `NO_GUIDE=1` on the make
command line.

## Run the full sweep on a SLURM cluster

`scripts/submit_sweep_by_seed.sh` submits one full sweep (5 configs x 2
cores) for a given seed:

```
./scripts/submit_sweep_by_seed.sh 1   # 10 jobs, ~10h each at cpus=4
squeue -u $USER
```

Tunable env vars at the top of the script: `CPUS_PER_TASK`, `MEMORY`,
`TIME_LIMIT`, `NUM_ITER_RKT`, `NUM_ITER_BOOM`. Output goes to
`server_runs/sweep/seed_<N>/...`, with one subdirectory per
(core, config). Each subdirectory contains a `cov_log_*.txt` once the
job has produced any coverage events.

To submit only a subset of variants, edit the `for CFG in ...` line
in the script.

## Reproducing our results

After one or more sweeps complete, aggregate the cov_logs and report
per-config geomean at the 9-hour mark:

```
python3 scripts/aggregate_cov_at_9h.py
```

Sample output:

```
Core    Config    n   GeoMean     Min       Max          vs base
----------------------------------------------------------------
rocket  nogu      2       80,300  80,117    80,484        -3.26%
rocket  baseline  3       83,003  82,420    83,855
rocket  pow       2       87,212  85,555    88,902        +5.07%
rocket  powrate   2       83,659  83,559    83,760        +0.79%
rocket  evict     2       83,226  83,085    83,368        +0.27%

boom    nogu      2      433,971  413,283   455,694       -10.53%
boom    baseline  5      485,055  474,945   496,691
boom    pow       3      495,892  487,673   500,939       +2.23%
boom    powrate   2      497,916  486,549   509,548       +2.65%
boom    evict     4      510,410  500,470   518,890       +5.23%
```

The script automatically discovers cov_log files anywhere under
`server_runs/`, classifies each by core (`rocket` / `boom`) and config,
filters out aborted partial runs, and reports geomean coverage at the
9-hour wall-clock check-point.

## Verifying the dispatch

Each run prints a banner at startup. After completion you can
sanity-check that the requested scheduler was actually used:

```
grep "DIFUZZ_SCHED =" slurm_logs/*.out | head
```

Each line should match the corresponding job name.

## Deliverables

`deliverables/` contains the project artefacts:

- `report.pdf` --- IEEE conference-format report
- `presentation.pdf` --- 5-minute talk
- `demo.pdf` --- tool demo slides
- `cov_logs.tar.gz` --- the raw `cov_log_*.txt` files we used to compute
  the headline numbers (small, useful for independent re-analysis)

## Citing the upstream work

```
J. Hur, S. Song, D. Kwon, E. Baek, J. Kim, and B. Lee.
DifuzzRTL: Differential fuzz testing to find CPU bugs.
IEEE Symposium on Security and Privacy, 2021.
```

## License

Original DifuzzRTL license retained (see `LICENSE`). Modifications by
Team-Assert are released under the same terms.
