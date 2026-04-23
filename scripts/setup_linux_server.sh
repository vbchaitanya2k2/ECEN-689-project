#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
jobs="${JOBS:-$(nproc)}"
missing=()
install_host_deps=0
if [ "${1:-}" = "--install-apt-deps" ] || [ "${1:-}" = "--install-host-deps" ]; then
    install_host_deps=1
fi

verilator_version_min="4.106"
verilator_source_tag="v4.106"
riscv_toolchain_tag="2021.04.23"

apt_packages=(
    git
    make
    python3
    python3-venv
    python3-pip
    gcc
    g++
    autoconf
    automake
    libtool
    pkg-config
    flex
    bison
    device-tree-compiler
    verilator
    gcc-riscv64-unknown-elf
    binutils-riscv64-unknown-elf
    picolibc-riscv64-unknown-elf
    zlib1g-dev
    libboost-dev
    libboost-regex-dev
    libboost-system-dev
    libboost-filesystem-dev
)

dnf_packages=(
    git
    make
    python3
    python3-pip
    python3-devel
    gcc
    gcc-c++
    autoconf
    automake
    libtool
    pkgconf-pkg-config
    flex
    bison
    dtc
    zlib-devel
    expat-devel
    gmp-devel
    mpfr-devel
    libmpc-devel
    gawk
    texinfo
    gperf
    patchutils
    bc
    cmake
    ninja-build
    ncurses-devel
    libslirp-devel
    boost-devel
    perl
)

install_with_apt() {
    if ! command -v apt-get >/dev/null 2>&1; then
        return 1
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y "${apt_packages[@]}"
    elif [ "$(id -u)" -eq 0 ]; then
        apt-get update
        apt-get install -y "${apt_packages[@]}"
    else
        echo "No usable sudo privileges for apt-based install."
        return 1
    fi
}

install_with_dnf() {
    if ! command -v dnf >/dev/null 2>&1; then
        return 1
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        sudo dnf install -y "${dnf_packages[@]}"
    elif [ "$(id -u)" -eq 0 ]; then
        dnf install -y "${dnf_packages[@]}"
    else
        echo "No usable sudo privileges for dnf-based install."
        return 1
    fi
}

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        missing+=("$1")
    fi
}

check_required_cmds() {
    missing=()
    for cmd in git make python3 gcc g++ autoreconf flex bison; do
        need_cmd "${cmd}"
    done

    for cmd in verilator riscv64-unknown-elf-gcc riscv64-unknown-elf-objcopy riscv64-unknown-elf-objdump dtc; do
        need_cmd "${cmd}"
    done
}

version_ge() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

build_verilator_from_source() {
    mkdir -p .local-src .local-tools
    if [ ! -d .local-src/verilator/.git ]; then
        git clone https://github.com/verilator/verilator .local-src/verilator
    fi

    pushd .local-src/verilator >/dev/null
    git fetch --tags --force
    git checkout "${verilator_source_tag}"
    autoconf
    ./configure --prefix="${repo_root}/.local-tools/verilator"
    make -j"${jobs}"
    make install
    popd >/dev/null
}

build_riscv_toolchain_from_source() {
    mkdir -p .local-src .local-tools/riscv .local-src/distfiles
    if [ ! -d .local-src/riscv-gnu-toolchain/.git ]; then
        git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git .local-src/riscv-gnu-toolchain
    fi

    pushd .local-src/riscv-gnu-toolchain >/dev/null
    git fetch --tags --force
    git checkout "${riscv_toolchain_tag}"
    export DISTDIR="${repo_root}/.local-src/distfiles"
    ./configure --prefix="${repo_root}/.local-tools/riscv"
    make -j"${jobs}"
    popd >/dev/null
}

check_required_cmds

if [ "${#missing[@]}" -ne 0 ]; then
    if [ "${install_host_deps}" -eq 1 ]; then
        if command -v apt-get >/dev/null 2>&1; then
            if ! install_with_apt; then
                echo "Host-package install was requested, but this account cannot use apt as root."
                echo "Retry without --install-host-deps to use the no-sudo local-build path."
                exit 1
            fi
        elif command -v dnf >/dev/null 2>&1; then
            if ! install_with_dnf; then
                echo "Host-package install was requested, but this account cannot use dnf as root."
                echo "Retry without --install-host-deps to use the no-sudo local-build path."
                exit 1
            fi
        else
            echo "Automatic package installation requested, but neither apt-get nor dnf is available on this host."
            exit 1
        fi
        check_required_cmds
    fi
fi

cd "${repo_root}"

if command -v verilator >/dev/null 2>&1; then
    verilator_version="$(verilator --version | awk '{print $2}')"
    if ! version_ge "${verilator_version}" "${verilator_version_min}"; then
        echo "System Verilator ${verilator_version} is older than ${verilator_version_min}; building ${verilator_source_tag} locally."
        build_verilator_from_source
    fi
elif [ -x "${repo_root}/.local-tools/verilator/bin/verilator" ]; then
    :
else
    echo "Verilator not found; building ${verilator_source_tag} locally."
    build_verilator_from_source
fi

export PATH="${repo_root}/.local-tools/verilator/bin:${repo_root}/.local-tools/riscv/bin:${repo_root}/.local-tools/bin:${repo_root}/.venv/bin:${PATH}"

if ! command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
    echo "Bare-metal RISC-V GNU toolchain not found; building ${riscv_toolchain_tag} locally."
    build_riscv_toolchain_from_source
fi

check_required_cmds

if [ "${#missing[@]}" -ne 0 ]; then
    cat <<EOF
Missing host tools: ${missing[*]}

Install or load these before running this script.
Typical Ubuntu packages:
  git make python3 python3-venv python3-pip gcc g++ autoconf automake libtool
  flex bison device-tree-compiler verilator
  gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

If your distro splits bare-metal headers, also install the matching picolibc/newlib package.

If this is a supported Linux machine and you have sudo, rerun:
  bash scripts/setup_linux_server.sh --install-host-deps
EOF
    exit 1
fi

python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install cocotb==1.5.2 psutil sysv_ipc pypdf

mkdir -p .local-src .local-tools

if [ ! -d .local-src/elf2hex/.git ]; then
    git clone https://github.com/sifive/elf2hex.git .local-src/elf2hex
fi

pushd .local-src/elf2hex >/dev/null
autoreconf -i
./configure --target=riscv64-unknown-elf --prefix="${repo_root}/.local-tools"
make -j"${jobs}"
make install
popd >/dev/null

pushd Fuzzer/ISASim/riscv-isa-sim >/dev/null
mkdir -p build
pushd build >/dev/null
../configure --prefix="$PWD"
make -j"${jobs}"
popd >/dev/null
popd >/dev/null

cat <<EOF
Setup complete.

Next steps:
  source scripts/env.local.sh
  bash scripts/run_repro.sh rocket 1000
EOF
