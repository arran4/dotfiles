#!/usr/bin/env python3
"""Offline tests for canonical PR repository resolution; no gh/network access."""
import importlib.util
import pathlib
import unittest
from unittest.mock import patch

script_path = pathlib.Path(__file__).with_name("fetch_comments.py")
spec = importlib.util.spec_from_file_location("fetch_comments", script_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


class PrUrlTests(unittest.TestCase):
    def test_fork_based_pr_uses_base_repo(self):
        with patch.object(module, "gh_pr_view_json", return_value={
            "number": 42, "url": "https://github.com/upstream/repo/pull/42"
        }):
            self.assertEqual(module.get_current_pr_ref(), ("upstream", "repo", 42))

    def test_inconsistent_number_rejected(self):
        with patch.object(module, "gh_pr_view_json", return_value={
            "number": 43, "url": "https://github.com/upstream/repo/pull/42"
        }):
            with self.assertRaises(ValueError):
                module.get_current_pr_ref()

    def test_invalid_url_rejected(self):
        for url in ["https://github.com/upstream/repo/issues/42", "not-a-url",
                    "https://github.com/upstream/repo/pull/not-a-number"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                module.parse_pr_url(url)


if __name__ == "__main__":
    unittest.main()
