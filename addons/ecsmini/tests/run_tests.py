"""Run ECSmini headless contracts and a small correctness-checked benchmark."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys


def run(command: list[str], cwd: Path, timeout: int = 90) -> str:
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=timeout)
    output = result.stdout + result.stderr
    print(output, end="" if output.endswith("\n") else "\n")
    if (result.returncode != 0 or "SCRIPT ERROR:" in output or "ERROR:" in output
            or "ObjectDB instances were leaked" in output):
        raise RuntimeError(f"Command failed: {' '.join(command)}")
    return output


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot"))
    parser.add_argument("--benchmark-only", action="store_true")
    options = parser.parse_args()
    if not options.godot:
        parser.error("Pass --godot with the installed Godot console executable.")
    project = Path(__file__).resolve().parents[3]
    prefix = [options.godot, "--headless", "--path", str(project)]
    try:
        run(prefix + ["--editor", "--quit"], project, timeout=180)
        if not options.benchmark_only:
            for test in sorted(Path(__file__).parent.glob("*_test.gd")):
                run(prefix + ["--script", str(test)], project)
            smoke = project / "addons/ecsmini/examples/example_smoke_test.gd"
            run(prefix + ["--script", str(smoke)], project, timeout=120)
        benchmark = project / "addons/ecsmini/benchmarks/runtime_benchmark.gd"
        if not benchmark.is_file():
            raise RuntimeError("Runtime benchmark is missing.")
        output = run(prefix + ["--script", str(benchmark), "--", "--counts=100",
                               "--samples=2", "--iterations=4", "--warmup=1"], project)
        marker = "ECSMINI_BENCHMARK_JSON="
        report_lines = [line[len(marker):] for line in output.splitlines()
                        if line.startswith(marker)]
        if len(report_lines) != 1:
            raise RuntimeError("Benchmark must emit exactly one JSON report.")
        report = json.loads(report_lines[0])
        if report.get("failures"):
            raise RuntimeError(f"Benchmark correctness failures: {report['failures']}")
        scenarios = {entry["scenario"] for entry in report["results"]}
        if scenarios != {"movement", "static_query", "unrelated_changes", "spawn_destroy"}:
            raise RuntimeError("Benchmark does not cover all required scenarios.")
        for entry in report["results"]:
            if entry["entity_count"] != 100 or len(entry["samples_usec"]) != 2:
                raise RuntimeError("Benchmark did not honor requested population/sample counts.")
            if not entry["correct"] or entry["median_usec"] < 0:
                raise RuntimeError("Benchmark produced an invalid result.")
        print("PASS: ECSmini benchmark contract")
        advanced = project / "addons/ecsmini/benchmarks/advanced_benchmark.gd"
        output = run(prefix + ["--script", str(advanced), "--", "--counts=17,257",
                               "--samples=2", "--iterations=3", "--chunk-size=64"], project)
        marker = "ECSMINI_ADVANCED_BENCHMARK_JSON="
        lines = [line[len(marker):] for line in output.splitlines() if line.startswith(marker)]
        if len(lines) != 1:
            raise RuntimeError("Advanced benchmark must emit one JSON report.")
        report = json.loads(lines[0])
        if report.get("failures") or len(report["results"]) != 24:
            raise RuntimeError("Advanced benchmark did not pass every configuration.")
        configurations = {(row["backend"], row["scenario"], row["requested_mode"], row["entity_count"])
                          for row in report["results"]}
        expected = {(backend, dimension, mode, count)
                    for backend in ("sparse", "archetype")
                    for dimension in ("movement_2d", "movement_3d")
                    for mode in ("serial", "parallel", "auto") for count in (17, 257)}
        if configurations != expected:
            raise RuntimeError("Advanced benchmark lacks requested backend/dimension/mode coverage.")
        for row in report["results"]:
            if not row["correct"] or len(row["total_samples_usec"]) != 2:
                raise RuntimeError("Invalid advanced correctness/sample result.")
            if row["requested_mode"] in ("serial", "parallel") and row["effective_mode"] != row["requested_mode"]:
                raise RuntimeError("Explicit advanced benchmark mode was not honored.")
            if row["requested_mode"] == "auto" and row["effective_mode"] not in ("serial", "parallel"):
                raise RuntimeError("Automatic advanced benchmark mode resolved unexpectedly.")
        print("PASS: ECSmini advanced storage/compute benchmark contract")
    except (RuntimeError, subprocess.TimeoutExpired, KeyError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
