# Portable Linux Server Workflow

## Can This Laptop Handle It?

Yes for short and medium runs.

Current local machine:

- AMD Ryzen 5 4600H
- 6 cores / 12 threads
- 16 GB RAM on Windows
- current WSL allocation observed: about 7.4 GB RAM

That is enough for:

- smoke testing
- 100 to 1000 iteration Rocket runs
- basic course-project reproduction work

Use the university server if you want:

- repeated multi-seed runs
- longer BOOM runs
- overnight experiments
- less risk from laptop sleep, thermals, or WSL memory limits

## What Is Portable

The source tree is portable.

Do not copy generated local artifacts such as:

- `.venv/`
- `.local-src/`
- `.local-tools/`
- `elf2hex/`
- `repro_runs/`
- `server_runs/`
- `Fuzzer/ISASim/riscv-isa-sim/build/`

Use the export script to package a clean archive:

```bash
bash scripts/export_portable_repo.sh
```

## Server Steps

1. Copy the generated tarball to the Linux server.
2. Extract it.
3. Make sure the server has these base tools installed or available through modules:

```bash
git make python3 python3-venv python3-pip gcc g++ autoconf automake libtool
flex bison device-tree-compiler verilator
gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

If your distro splits bare-metal headers, also install the matching `picolibc` or `newlib` package.

4. From the extracted repo root, run:

```bash
bash scripts/setup_linux_server.sh --install-host-deps
source scripts/env.local.sh
bash scripts/run_repro.sh rocket 1000
```

For BOOM:

```bash
bash scripts/run_repro.sh boom13 1000
```

On RHEL-like machines, the script can install build dependencies with `dnf` and then build a local `verilator` and bare-metal RISC-V toolchain from source when the distro does not provide suitable packages.

If you do not have `sudo`, do not use `--install-host-deps`. Run the plain setup command instead and let it build user-local tools under `.local-tools/`:

```bash
bash scripts/setup_linux_server.sh
```

## Runtime Expectations

Measured locally after the simulator was already compiled:

- Rocket guided, 100 iterations: about 6.4 minutes
- Rocket random, 100 iterations: about 5.7 minutes

Rough planning numbers:

- 1000 iterations: about 1 hour
- 5000 iterations: several hours
- multi-seed Rocket plus BOOM: better suited to a server

## Current Reproduction Status

Completed locally:

- WSL bring-up
- toolchain bring-up
- Rocket smoke run
- Rocket guided vs random short run

Not completed yet:

- long multi-seed Rocket runs
- BOOM reproduction
- final plots for a paper-style comparison
