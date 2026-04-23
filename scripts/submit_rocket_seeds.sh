#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

num_seeds="${1:-3}"
num_iter="${2:-1000}"
cpus="${CPUS_PER_TASK:-4}"
mem="${MEMORY_PER_JOB:-16G}"
time_limit="${TIME_LIMIT:-08:00:00}"
server_runs_root="${OUT_BASE:-${repo_root}/server_runs}"
log_root="${LOG_BASE:-${repo_root}/slurm_logs}"

mkdir -p "${log_root}"

for seed in $(seq 1 "${num_seeds}"); do
    out_root="${server_runs_root}/rocket-${num_iter}-seed${seed}"
    guided_out="${out_root}/rocket-guided"
    random_out="${out_root}/rocket-random"
    build_dir="${out_root}/build-rocket"

    guided_cmd="cd ${repo_root}/Fuzzer && . ../scripts/env.local.sh && unset C_INCLUDE_PATH CPATH CPLUS_INCLUDE_PATH && make SIM_BUILD=${build_dir} VFILE=RocketTile_state TOPLEVEL=RocketTile NUM_ITER=${num_iter} OUT=${guided_out} RECORD=1"
    random_cmd="cd ${repo_root}/Fuzzer && . ../scripts/env.local.sh && unset C_INCLUDE_PATH CPATH CPLUS_INCLUDE_PATH && make SIM_BUILD=${build_dir} VFILE=RocketTile_state TOPLEVEL=RocketTile NUM_ITER=${num_iter} OUT=${random_out} RECORD=1 NO_GUIDE=1"

    guided_job="$(sbatch \
        --parsable \
        --job-name="difuzz-rkt-g${seed}" \
        --cpus-per-task="${cpus}" \
        --mem="${mem}" \
        --time="${time_limit}" \
        --output="${log_root}/difuzz-rkt-guided-seed${seed}-%j.out" \
        --wrap="${guided_cmd}")"

    random_job="$(sbatch \
        --parsable \
        --dependency="afterok:${guided_job}" \
        --job-name="difuzz-rkt-r${seed}" \
        --cpus-per-task="${cpus}" \
        --mem="${mem}" \
        --time="${time_limit}" \
        --output="${log_root}/difuzz-rkt-random-seed${seed}-%j.out" \
        --wrap="${random_cmd}")"

    printf 'seed %s guided_job=%s random_job=%s\n' "${seed}" "${guided_job}" "${random_job}"
done

