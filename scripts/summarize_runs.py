#!/usr/bin/env python3
import argparse
import csv
import math
from pathlib import Path


def parse_cov_log(path: Path):
    rows = []
    if not path.exists():
        return rows
    with path.open() as f:
        reader = csv.reader(f, delimiter="\t")
        for row in reader:
            cols = [c.strip() for c in row if c.strip()]
            if len(cols) != 3 or cols[0] == "time":
                continue
            try:
                rows.append((float(cols[0]), int(cols[1]), int(cols[2])))
            except ValueError:
                continue
    return rows


def find_cov_log(run_dir: Path):
    logs = sorted(run_dir.glob("cov_log_*.txt"))
    return logs[-1] if logs else None


def count_files(path: Path):
    if not path.exists():
        return 0
    return sum(1 for child in path.rglob("*") if child.is_file())


def summarize_run(run_dir: Path):
    cov_log = find_cov_log(run_dir)
    rows = parse_cov_log(cov_log) if cov_log else []
    final_time = rows[-1][0] if rows else math.nan
    final_iter = rows[-1][1] if rows else -1
    final_cov = rows[-1][2] if rows else -1
    mismatch_count = count_files(run_dir / "mismatch" / "sim_input")
    illegal_count = count_files(run_dir / "illegal")
    corpus_count = count_files(run_dir / "corpus")
    return {
        "run_dir": str(run_dir),
        "final_time_s": final_time,
        "final_iter": final_iter,
        "final_cov": final_cov,
        "mismatch_inputs": mismatch_count,
        "illegal_files": illegal_count,
        "corpus_files": corpus_count,
    }


def mean(values):
    vals = [v for v in values if isinstance(v, (int, float)) and not math.isnan(v)]
    return sum(vals) / len(vals) if vals else math.nan


def main():
    parser = argparse.ArgumentParser(description="Summarize DIFUZZ run directories.")
    parser.add_argument("runs", nargs="+", help="Run directories such as rocket-guided or rocket-random")
    args = parser.parse_args()

    summaries = [summarize_run(Path(run)) for run in args.runs]

    print("run_dir\tfinal_time_s\tfinal_iter\tfinal_cov\tmismatch_inputs\tillegal_files\tcorpus_files")
    for item in summaries:
        print(
            f"{item['run_dir']}\t"
            f"{item['final_time_s']:.2f}\t"
            f"{item['final_iter']}\t"
            f"{item['final_cov']}\t"
            f"{item['mismatch_inputs']}\t"
            f"{item['illegal_files']}\t"
            f"{item['corpus_files']}"
        )

    print()
    print("averages")
    print(f"final_time_s\t{mean([item['final_time_s'] for item in summaries]):.2f}")
    print(f"final_cov\t{mean([item['final_cov'] for item in summaries]):.2f}")
    print(f"mismatch_inputs\t{mean([item['mismatch_inputs'] for item in summaries]):.2f}")
    print(f"corpus_files\t{mean([item['corpus_files'] for item in summaries]):.2f}")


if __name__ == "__main__":
    main()
