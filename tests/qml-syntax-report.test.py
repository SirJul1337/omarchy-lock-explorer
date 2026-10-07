import json
from pathlib import Path
import subprocess
import unittest

REPORT = Path(__file__).resolve().parents[1] / "extras/qml-syntax-report.py"

class QmlReportTests(unittest.TestCase):
    def check_report(self, category, severity="warning"):
        report = {"files": [{"filename": "Service.qml", "warnings": [
            {"id": category, "type": severity, "message": "fixture", "line": 1}
        ]}]}
        return subprocess.run(["python3", str(REPORT), "1"], input=json.dumps(report),
                              text=True, capture_output=True).returncode

    def test_blocking_diagnostics(self):
        for category in ("syntax", "duplicated-name", "duplicate-property-binding"):
            with self.subTest(category=category):
                self.assertEqual(self.check_report(category), 1)
        self.assertEqual(self.check_report("other", "critical"), 1)

    def test_unavailable_import_warning_is_allowed(self):
        self.assertEqual(self.check_report("import"), 0)

    def test_invalid_report_fails(self):
        result = subprocess.run(["python3", str(REPORT)], input="invalid",
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)

if __name__ == "__main__":
    unittest.main()
