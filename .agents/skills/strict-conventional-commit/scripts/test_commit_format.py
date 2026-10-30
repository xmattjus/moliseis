import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import unittest

import commit_format as formatter


PAYLOAD = {
    "type": "fix",
    "scope": "commit",
    "description": "preserve generated arguments",
    "short_description": "preserve arguments",
    "body": "Keep user text intact when generating shell commands",
}
QUOTES = "'‘’‚‛"
ATTACKS = [
    f"Safe{quote} ; Write-Output injected; #" for quote in QUOTES
] + [QUOTES * 2, '"$HOME $(Write-Output injected) `n & | < > \\ café\nnext']
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell")


class FormatterTests(unittest.TestCase):
    def test_powershell_escapes_every_quote_without_changing_text(self):
        for value in ATTACKS:
            with self.subTest(value=value):
                quoted = formatter.powershell_quote(value)
                self.assertEqual(quoted[0], "'")
                self.assertEqual(quoted[-1], "'")
                # Scan pairs using PowerShell's single-quoted-string grammar.
                decoded = []
                index = 1
                while index < len(quoted) - 1:
                    char = quoted[index]
                    if char in QUOTES:
                        self.assertEqual(quoted[index + 1], char)
                        index += 1
                    decoded.append(char)
                    index += 1
                self.assertEqual("".join(decoded), value)

    @unittest.skipUnless(POWERSHELL, "PowerShell is not installed")
    def test_powershell_runtime_argument_capture(self):
        for value in ATTACKS:
            payload = dict(PAYLOAD, body=value)
            command = formatter.format_commit(payload, "powershell")
            capture = command.replace("git commit ", "Capture ", 1)
            script = (
                "function Capture { ConvertTo-Json -Compress -InputObject @($args) }; "
                + capture
            )
            result = subprocess.run(
                [POWERSHELL, "-NoProfile", "-NonInteractive", "-Command", script],
                text=True, capture_output=True, check=True,
            )
            expected = shlex.split(formatter.format_commit(payload, "posix"))[2:]
            self.assertEqual(json.loads(result.stdout), expected)

    def test_breaking_footer_first_word_boundaries(self):
        for length in (54, 55, 56, 57, 71, 72, 73):
            for suffix in ("", " next"):
                with self.subTest(length=length, suffix=suffix):
                    payload = dict(PAYLOAD, breaking="x" * length + suffix)
                    command = formatter.format_commit(payload, "posix")
                    first_word_length = length + (not suffix)
                    if first_word_length > 55:
                        self.assertTrue(command.startswith("ERROR "))
                    else:
                        footer = shlex.split(command)[-1]
                        self.assertTrue(footer.startswith("BREAKING CHANGE: x"))
                        self.assertTrue(all(len(line) <= 72 for line in footer.splitlines()))

    def test_posix_quoting_body_and_footer(self):
        for value in ATTACKS:
            payload = dict(PAYLOAD, body=value, breaking="Require explicit quoting " * 8)
            command = formatter.format_commit(payload, "posix")
            args = shlex.split(command)
            self.assertEqual(args[:3], ["git", "commit", "-m"])
            self.assertIn("!:", args[3])
            self.assertEqual(args[5], formatter.wrap(formatter.sentence(value)))
            self.assertTrue(args[7].startswith("BREAKING CHANGE: Require"))
            self.assertTrue(all(len(line) <= 72 for text in args[5::2] for line in text.splitlines()))

    def test_header_limits_and_title_mode(self):
        for length in (50, 51, 60, 61):
            payload = dict(PAYLOAD, scope="", description="x" * (length - 5),
                           short_description="x" * (length - 5))
            title = formatter.format_commit(payload, "posix", pr_title=True)
            self.assertEqual(title.startswith("ERROR "), length > 60)
            if length <= 60:
                self.assertEqual(len(title), length)
        payload = dict(PAYLOAD, body="", breaking="x" * 72)
        self.assertEqual(formatter.format_commit(payload, "posix"), "ERROR empty_body")
        self.assertEqual(formatter.format_commit(payload, "posix", pr_title=True),
                         "fix(commit)!: preserve generated arguments")

    def test_cli_title_needs_no_body(self):
        payload = dict(PAYLOAD)
        del payload["body"]
        result = subprocess.run(
            [sys.executable, "-B", str(Path(formatter.__file__)), "--pr-title"],
            input=json.dumps(payload), text=True, capture_output=True, check=True,
        )
        self.assertEqual(result.stdout.strip(), "fix(commit): preserve generated arguments")

    def test_classifier_keeps_consumer_compatibility(self):
        skill = (Path(__file__).parents[1] / "SKILL.md").read_text()
        self.assertIn("| tests/docs/CI/AI harness only | usually NO |", skill)
        self.assertIn("| CLI command/flag removed or renamed | YES |", skill)
        self.assertIn("If existing consumers still work unchanged, it is not", skill)


if __name__ == "__main__":
    unittest.main()
