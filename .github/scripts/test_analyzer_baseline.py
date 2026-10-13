"""Regression checks for the gate's failure handling and diagnostic identity."""

import collections
from pathlib import Path
import tempfile
import unittest

from analyzer_baseline import compare, parse_diagnostics


class AnalyzerBaselineTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / "base"
        self.current = self.root / "current"
        self.base.mkdir()
        self.current.mkdir()
        for root in (self.base, self.current):
            (root / "sample.dart").write_text("\nlegacy();\nnewCode();\n")

    def report(self, severity="info", row=2, code="legacy_lint", message="Legacy finding"):
        return (
            f"   {severity} • {message} • sample.dart:{row}:1 • {code}\n"
            "1 issue found. (ran in 1.0s)\n"
        )

    def parse(self, output, root=None):
        return parse_diagnostics(root or self.current, output, 1)

    def compare(self, before, after):
        return compare(before, after, self.base, self.current)

    def test_existing_diagnostic_and_line_shift_pass(self):
        before = self.parse(self.report())
        (self.current / "sample.dart").write_text("// inserted\n\nlegacy();\nnewCode();\n")
        after = self.parse(self.report(row=3))
        self.assertTrue(self.compare(before, after))

    def test_new_occurrence_fails_even_when_total_is_unchanged(self):
        before = self.parse(self.report())
        after = self.parse(self.report(row=3))
        self.assertFalse(self.compare(before, after))

    def test_removed_occurrence_cannot_pay_for_new_identical_line_elsewhere(self):
        (self.base / "sample.dart").write_text("a() {\nlegacy();\n}\nb() {\n}\n")
        (self.current / "sample.dart").write_text("a() {\n}\nb() {\nlegacy();\n}\n")
        before = self.parse(self.report(row=2), self.base)
        after = self.parse(self.report(row=4))
        self.assertFalse(self.compare(before, after))

    def test_duplicate_occurrence_is_not_deduplicated(self):
        before = self.parse(self.report())
        self.assertFalse(self.compare(before, before + before))

    def test_severity_increase_and_new_code_fail(self):
        before = self.parse(self.report())
        self.assertFalse(self.compare(before, self.parse(self.report(severity="warning"))))
        self.assertFalse(self.compare(before, self.parse(self.report(code="new_lint"))))

    def test_removing_debt_passes(self):
        self.assertTrue(self.compare(self.parse(self.report()), collections.Counter()))

    def test_errors_always_fail_including_existing_errors(self):
        with self.assertRaisesRegex(ValueError, "always blocking"):
            self.parse(self.report(severity="error"))

    def test_crash_missing_summary_and_incomplete_output_fail(self):
        for output, status in (
            ("Analysis server crashed", 1),
            (self.report().replace("1 issue", "2 issues"), 1),
            (self.report(), 2),
            (self.report(), 0),
            (self.report().replace("info •", "unknown •"), 1),
        ):
            with self.subTest(output=output, status=status), self.assertRaises(ValueError):
                parse_diagnostics(self.current, output, status)

    def test_clean_analysis_requires_success(self):
        output = "No issues found! (ran in 1.0s)\n"
        self.assertEqual(parse_diagnostics(self.current, output, 0), collections.Counter())
        with self.assertRaises(ValueError):
            parse_diagnostics(self.current, output, 1)


if __name__ == "__main__":
    unittest.main()
