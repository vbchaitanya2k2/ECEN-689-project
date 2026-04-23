#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

if [ ! -f "${script_dir}/env.local.sh" ]; then
    echo "Missing scripts/env.local.sh"
    exit 1
fi

. "${script_dir}/env.local.sh"

target="${1:-rocket}"
num_iter="${2:-1000}"
run_stamp="$(date +%Y%m%d-%H%M%S)"
out_root="${3:-${repo_root}/server_runs/${target}-${num_iter}-${run_stamp}}"

case "${target}" in
    rocket)
        vfile="RocketTile_state"
        toplevel="RocketTile"
        ;;
    boom13)
        vfile="SmallBoomTile_v1.3_state"
        toplevel="BoomTile"
        ;;
    boom12)
        vfile="SmallBoomTile_v1.2_state"
        toplevel="BoomTile"
        ;;
    *)
        echo "Usage: bash scripts/run_repro.sh [rocket|boom13|boom12] [num_iter] [out_dir]"
        exit 1
        ;;
esac

if ! command -v elf2hex >/dev/null 2>&1; then
    echo "elf2hex not found in PATH. Run: bash scripts/setup_linux_server.sh"
    exit 1
fi

if [ ! -x "${SPIKE}" ]; then
    echo "Spike not found at ${SPIKE}. Run: bash scripts/setup_linux_server.sh"
    exit 1
fi

mkdir -p "${out_root}"
build_dir="${out_root}/build-${target}"
guided_out="${out_root}/${target}-guided"
random_out="${out_root}/${target}-random"

pushd "${repo_root}/Fuzzer" >/dev/null

echo "Running guided fuzzing for ${target} with ${num_iter} iterations"
/usr/bin/time -p make \
    SIM_BUILD="${build_dir}" \
    VFILE="${vfile}" \
    TOPLEVEL="${toplevel}" \
    NUM_ITER="${num_iter}" \
    OUT="${guided_out}" \
    RECORD=1 \
    2>&1 | tee "${out_root}/guided.log"

echo "Running random fuzzing for ${target} with ${num_iter} iterations"
/usr/bin/time -p make \
    SIM_BUILD="${build_dir}" \
    VFILE="${vfile}" \
    TOPLEVEL="${toplevel}" \
    NUM_ITER="${num_iter}" \
    OUT="${random_out}" \
    RECORD=1 \
    NO_GUIDE=1 \
    2>&1 | tee "${out_root}/random.log"

popd >/dev/null

echo "Results written to ${out_root}"
