#!/usr/bin/env bash

# Source this file before running the fuzzer on Linux/WSL.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

export PATH="${repo_root}/.local-tools/verilator/bin:${repo_root}/.local-tools/riscv/bin:${repo_root}/.local-tools/bin:${repo_root}/.venv/bin:${PATH}"
export RISCV="${repo_root}/.local-tools/riscv"
export SPIKE="${repo_root}/Fuzzer/ISASim/riscv-isa-sim/build/spike"
export PYTHONPATH="${repo_root}/Fuzzer:${repo_root}/Fuzzer/src:${repo_root}/Fuzzer/RTLSim/src${PYTHONPATH:+:${PYTHONPATH}}"

for include_dir in \
    "/usr/lib/picolibc/riscv64-unknown-elf/include" \
    "/usr/riscv64-unknown-elf/include" \
    "/opt/riscv/riscv64-unknown-elf/include" \
    "${RISCV:-}/riscv64-unknown-elf/include"
do
    if [ -n "${include_dir}" ] && [ -d "${include_dir}" ]; then
        export C_INCLUDE_PATH="${include_dir}${C_INCLUDE_PATH:+:${C_INCLUDE_PATH}}"
        export CPATH="${include_dir}${CPATH:+:${CPATH}}"
        break
    fi
done
