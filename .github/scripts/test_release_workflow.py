#!/usr/bin/env python3
"""Static invariants for the CI release entry points (no external YAML deps)."""

from pathlib import Path
import re
import unittest

WORKFLOW = Path(__file__).resolve().parents[1] / "workflows" / "ci.yml"


def job_body(workflow, name):
    match = re.search(r"(?m)^  " + re.escape(name) + r":\n", workflow)
    if match is None:
        raise AssertionError(f"missing job {name}")
    remainder = workflow[match.end():]
    next_job = re.search(r"(?m)^  [a-z][a-z0-9-]*:\n", remainder)
    return remainder[:next_job.start()] if next_job else remainder


class ReleaseWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_release_mutations_wait_for_checks(self):
        for job in ("manual-release-tag", "package-dotfiles", "docker-release"):
            with self.subTest(job=job):
                body = job_body(self.workflow, job)
                self.assertRegex(body, r"needs: \[[^\]]*shell-check, gitleaks\]")
                self.assertIn("needs.shell-check.result == 'success'", body)
                self.assertIn("needs.gitleaks.result == 'success'", body)

    def test_docker_build_writes_only_versioned_tag(self):
        body = job_body(self.workflow, "docker-release")
        self.assertIn("latest=false", body)
        self.assertIn("type=raw,value=${{ github.ref_name }}", body)
        self.assertNotIn("type=semver", body)
        self.assertNotIn("type=raw,value=latest", body)

    def test_alias_promotion_is_ordered_and_checked(self):
        body = job_body(self.workflow, "publish-image-aliases")
        self.assertIn("needs.docker-release.result == 'success'", body)
        self.assertIn("queue: max", body)
        self.assertIn("cancel-in-progress: false", body)
        self.assertIn("release_aliases.py", body)
        self.assertIn("imagetools create", body)

    def test_version_tag_creation_is_queued(self):
        body = job_body(self.workflow, "manual-release-tag")
        self.assertIn("queue: max", body)
        self.assertIn("cancel-in-progress: false", body)

    def test_release_runs_not_cancelled_by_non_release_ci(self):
        front = self.workflow.split("jobs:\n", 1)[0]
        self.assertIn("format('release-{0}', github.run_id)", front)
        self.assertIn("inputs.mode == 'publish-tag'", front)
        self.assertIn("cancel-in-progress: ${{ !(", front)

    def test_safety_suite_runs_during_code_checks(self):
        body = job_body(self.workflow, "shell-check")
        self.assertIn("python3 -m unittest discover", body)
        self.assertIn("test_release_*.py", body)


if __name__ == "__main__":
    unittest.main()
