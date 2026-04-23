#!/usr/bin/env python3
import argparse
import csv
import math
from pathlib import Path


def parse_cov_log(run_dir: Path):
    logs = sorted(run_dir.glob("cov_log_*.txt"))
    if not logs:
        raise FileNotFoundError(f"no cov_log_*.txt found under {run_dir}")

    rows = []
    with logs[-1].open() as f:
        reader = csv.reader(f, delimiter="\t")
        for row in reader:
            cols = [c.strip() for c in row if c.strip()]
            if len(cols) != 3 or cols[0] == "time":
                continue
            rows.append((float(cols[0]), int(cols[1]), int(cols[2])))

    if not rows:
        raise ValueError(f"no coverage rows found in {logs[-1]}")

    return rows


def coverage_at(rows, target_seconds: float):
    cov = None
    it = None
    ts = None
    for row_time, row_iter, row_cov in rows:
        if row_time <= target_seconds:
            ts = row_time
            it = row_iter
            cov = row_cov
        else:
            break
    return ts, it, cov


def parse_labeled_run(spec: str):
    if "=" not in spec:
        raise argparse.ArgumentTypeError(
            f"run spec '{spec}' must be in label=path form"
        )
    label, path = spec.split("=", 1)
    if not label or not path:
        raise argparse.ArgumentTypeError(
            f"run spec '{spec}' must be in label=path form"
        )
    return label, Path(path)


def format_float(value):
    if value is None or math.isnan(value):
        return "n/a"
    return f"{value:.2f}"


def main():
    parser = argparse.ArgumentParser(
        description="Compare DIFUZZ runs at equal elapsed time points."
    )
    parser.add_argument(
        "runs",
        nargs="+",
        type=parse_labeled_run,
        help="Run directories in label=path form, e.g. reg-cov=server_runs/rocket-5000/rocket-guided",
    )
    parser.add_argument(
        "--times-hours",
        nargs="*",
        type=float,
        default=None,
        help="Explicit hour marks to compare. If omitted, uses integer hours up to the common horizon.",
    )
    args = parser.parse_args()

    data = {}
    final_times = []
    for label, run_dir in args.runs:
        rows = parse_cov_log(run_dir)
        data[label] = {
            "run_dir": run_dir,
            "rows": rows,
            "final_time_s": rows[-1][0],
            "final_iter": rows[-1][1],
            "final_cov": rows[-1][2],
        }
        final_times.append(rows[-1][0])

    common_horizon_s = min(final_times)
    common_horizon_h = common_horizon_s / 3600.0

    if args.times_hours:
        time_marks_h = args.times_hours
    else:
        max_whole_hours = int(common_horizon_h)
        time_marks_h = list(range(1, max_whole_hours + 1))
        if not time_marks_h:
            time_marks_h = [round(common_horizon_h, 2)]

    print("final_summary")
    print("label\trun_dir\tfinal_time_h\tfinal_iter\tfinal_cov")
    for label, item in data.items():
        print(
            f"{label}\t{item['run_dir']}\t"
            f"{item['final_time_s'] / 3600.0:.2f}\t"
            f"{item['final_iter']}\t"
            f"{item['final_cov']}"
        )

    print()
    print(f"common_horizon_h\t{common_horizon_h:.2f}")
    print()
    print("time_based_comparison")

    header = ["time_h"]
    for label in data:
        header += [f"{label}_cov", f"{label}_iter", f"{label}_sample_h"]
    print("\t".join(header))

    for hour_mark in time_marks_h:
        target_seconds = hour_mark * 3600.0
        row = [format_float(hour_mark)]
        for label, item in data.items():
            sample_t, sample_iter, sample_cov = coverage_at(item["rows"], target_seconds)
            row.append("n/a" if sample_cov is None else str(sample_cov))
            row.append("n/a" if sample_iter is None else str(sample_iter))
            row.append("n/a" if sample_t is None else f"{sample_t / 3600.0:.2f}")
        print("\t".join(row))


if __name__ == "__main__":
    main()
