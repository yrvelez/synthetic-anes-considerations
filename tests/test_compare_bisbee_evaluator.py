"""Saved-data evaluator integration checks; never calls a model API."""

import csv
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
TARGETS = {
    "Kamala Harris": "V241156",
    "Donald Trump": "V241157",
    "Joe Biden": "V241158",
    "RFK Jr": "V241159",
    "JD Vance": "V241164",
    "Tim Walz": "V241165",
    "Democratic Party": "V241166",
    "Republican Party": "V241167",
}


def write_csv(path, rows):
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


class EvaluatorChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.actual = []
        self.baseline = []
        self.zaller = []
        for respondent, value in enumerate((0, 20, 80, 100), start=1):
            self.actual.append({"V200001": respondent, **{column: value for column in TARGETS.values()}})
            for target in TARGETS:
                for draw in (1, 2):
                    row = {
                        "respID": respondent, "group": target, "prompt_type": "full", "draw": draw,
                        "thermometer": value, "confidence": 50,
                        "PID": "Democrat" if respondent <= 2 else "Republican",
                        "sampled_considerations": "test thought", "explanation": "test explanation",
                    }
                    self.baseline.append(row)
                    self.zaller.append({
                        **row, "thermometer": 100 - value,
                        "group": "Robert F. Kennedy Jr." if target == "RFK Jr" else target,
                    })

    def run_evaluator(self):
        for name, rows in (("actual", self.actual), ("baseline", self.baseline), ("zaller", self.zaller)):
            write_csv(self.directory / f"{name}.csv", rows)
        environment = {
            **os.environ,
            "ANES_FILE": str(self.directory / "actual.csv"),
            "BASELINE_FILE": str(self.directory / "baseline.csv"),
            "ZALLER_FILE": str(self.directory / "zaller.csv"),
            "OUT_FILE": str(self.directory / "report.md"),
            "EXPECTED_RESPONDENTS": "4", "RUN_LABEL": "integration_fixture",
        }
        return subprocess.run(
            ["Rscript", str(ROOT / "scripts" / "compare_bisbee_zaller_report.R")],
            cwd=ROOT, env=environment, text=True, capture_output=True, check=False,
        )

    def read_output(self, suffix):
        with (self.directory / f"report_{suffix}.csv").open() as handle:
            return list(csv.DictReader(handle))

    def test_alias_join_and_distribution_metrics(self):
        result = self.run_evaluator()
        self.assertEqual(result.returncode, 0, result.stderr)
        coverage = self.read_output("truth_coverage")
        self.assertEqual(len(coverage), 8)
        self.assertEqual(sum(int(row["valid_truth"]) for row in coverage), 32)
        rfk = next(row for row in coverage if row["group"] == "RFK Jr")
        self.assertEqual(rfk["zaller_matched"], "4")
        metrics = self.read_output("distribution_metrics")
        for row in metrics:
            if row["model"] == "Bisbee et al. (2024)" or row["subgroup_type"] == "all":
                self.assertAlmostEqual(float(row["tv_native_101"]), 0)
                self.assertAlmostEqual(float(row["w1_thermometer_points"]), 0)
            else:
                # Same pooled histogram, but people and party subgroups are reversed.
                self.assertAlmostEqual(float(row["tv_native_101"]), 1)
                self.assertAlmostEqual(float(row["tv_fixed_11_bins"]), 1)
                self.assertAlmostEqual(float(row["w1_thermometer_points"]), 80)
        individual = self.read_output("individual_metrics")
        self.assertEqual(individual[0]["rmse"], "0.00")
        self.assertGreater(float(individual[1]["rmse"]), 80)

    def test_invalid_truth_is_explicit_not_silent(self):
        self.actual[0]["V241159"] = -9
        result = self.run_evaluator()
        self.assertEqual(result.returncode, 0, result.stderr)
        rfk = next(row for row in self.read_output("truth_coverage") if row["group"] == "RFK Jr")
        self.assertEqual(rfk["valid_truth"], "3")
        self.assertEqual(rfk["missing_or_invalid_truth"], "1")
        self.assertEqual(rfk["baseline_matched"], "3")

    def test_missing_prediction_fails(self):
        self.zaller.pop()
        result = self.run_evaluator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("incomplete respondent-target-draw grid", result.stderr)

    def test_duplicate_prediction_fails(self):
        self.zaller.append(dict(self.zaller[0]))
        result = self.run_evaluator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate respondent-target-draw", result.stderr)

    def test_unknown_target_fails(self):
        self.zaller[0]["group"] = "Misspelled target"
        result = self.run_evaluator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown target name", result.stderr)

    def test_missing_truth_respondent_fails(self):
        self.actual.pop()
        result = self.run_evaluator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("truth rows do not uniquely cover", result.stderr)

    def test_raw_draws_are_not_binned_person_means(self):
        # A person's 0/100 mixture must not become a fabricated rating of 50.
        for row in self.baseline:
            row["thermometer"] = 0 if row["draw"] == 1 else 100
        for row in self.zaller:
            row["thermometer"] = 0 if row["draw"] == 1 else 100
        for row in self.actual:
            for column in TARGETS.values():
                row[column] = 0 if row["V200001"] <= 2 else 100
        result = self.run_evaluator()
        self.assertEqual(result.returncode, 0, result.stderr)
        for row in self.read_output("distribution_metrics"):
            if row["subgroup_type"] == "all":
                self.assertAlmostEqual(float(row["tv_native_101"]), 0)
                self.assertAlmostEqual(float(row["w1_thermometer_points"]), 0)


if __name__ == "__main__":
    unittest.main()
