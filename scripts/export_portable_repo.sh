#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
repo_name="$(basename -- "${repo_root}")"
parent_dir="$(dirname -- "${repo_root}")"
stamp="$(date +%Y%m%d-%H%M%S)"
output="${1:-${parent_dir}/${repo_name}-portable-${stamp}.tar.gz}"

mkdir -p "$(dirname -- "${output}")"

tar -C "${parent_dir}" -czf "${output}" \
    --exclude="${repo_name}/.venv" \
    --exclude="${repo_name}/.local-src" \
    --exclude="${repo_name}/.local-tools" \
    --exclude="${repo_name}/elf2hex" \
    --exclude="${repo_name}/repro_runs" \
    --exclude="${repo_name}/server_runs" \
    --exclude="${repo_name}/Fuzzer/results.xml" \
    --exclude="${repo_name}/Fuzzer/ISASim/riscv-isa-sim/build" \
    --exclude="${repo_name}/__pycache__" \
    --exclude="${repo_name}/*/__pycache__" \
    --exclude="${repo_name}/*.pyc" \
    "${repo_name}"

echo "Portable archive created at ${output}"
