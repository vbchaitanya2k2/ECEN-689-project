#!/usr/bin/env bash
# Submit a full 5-config x 2-core sweep for ONE seed.
# Usage: ./scripts/submit_sweep_by_seed.sh [SEED]
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

SEED="${1:-1}"
CPUS="${CPUS_PER_TASK:-4}"
MEM="${MEMORY:-24G}"
TIMELIM="${TIME_LIMIT:-11:59:00}"
NITER_RKT="${NUM_ITER_RKT:-15000}"
NITER_BOOM="${NUM_ITER_BOOM:-7000}"

LOG_DIR="${repo_root}/slurm_logs"
mkdir -p "${LOG_DIR}"

RKT_BUILD="${repo_root}/server_runs/rocket-15k/build-rocket"
BOOM_BUILD="${repo_root}/server_runs/boom13-7k/build-boom13"

[ -d "${RKT_BUILD}" ]  || { echo "ERROR: missing ${RKT_BUILD}" >&2; exit 1; }
[ -d "${BOOM_BUILD}" ] || { echo "ERROR: missing ${BOOM_BUILD}" >&2; exit 1; }

submit_one() {
    local core="$1" cfg="$2" sched="$3" extra="$4" vfile="$5" toplevel="$6" niter="$7" build="$8"
    local out="server_runs/sweep/seed_${SEED}/${core}-${cfg}"
    mkdir -p "${repo_root}/${out}"
    local wrap='cleanup(){ rm -rf '"${out}"'/corpus '"${out}"'/mismatch '"${out}"'/illegal '"${out}"'/err '"${out}"'/isa_timeout; find '"${out}"' \( -name "*.elf" -o -name "*.hex" -o -name "*.S" -o -name "*.si" \) -delete 2>/dev/null; }; trap cleanup EXIT TERM; cd '"${repo_root}"' && . scripts/env.local.sh && unset C_INCLUDE_PATH CPATH CPLUS_INCLUDE_PATH && export DIFUZZ_SCHED='"${sched}"' && cd Fuzzer && make SIM_BUILD='"${build}"' VFILE='"${vfile}"' TOPLEVEL='"${toplevel}"' NUM_ITER='"${niter}"' OUT=../'"${out}"' RECORD=1 '"${extra}"
    sbatch \
        --job-name="sw-${core:0:3}-${cfg}-s${SEED}" \
        --cpus-per-task="${CPUS}" --mem="${MEM}" --time="${TIMELIM}" \
        --output="${LOG_DIR}/sw-${core}-${cfg}-s${SEED}-%j.out" \
        --wrap="${wrap}"
}

for CFG in baseline pow powrate evict nogu; do
    if [ "${CFG}" = "nogu" ]; then EXTRA="NO_GUIDE=1"; SCHED="baseline"
    else                           EXTRA="";           SCHED="${CFG}"
    fi
    submit_one "rocket" "${CFG}" "${SCHED}" "${EXTRA}" "RocketTile_state"         "RocketTile" "${NITER_RKT}"  "${RKT_BUILD}"
    submit_one "boom"   "${CFG}" "${SCHED}" "${EXTRA}" "SmallBoomTile_v1.3_state" "BoomTile"   "${NITER_BOOM}" "${BOOM_BUILD}"
    sleep 1
done

echo "Submitted 10 jobs for SEED=${SEED}. Check: squeue -u \$USER"
