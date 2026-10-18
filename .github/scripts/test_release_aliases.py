#!/usr/bin/env python3
"""Offline regression tests for the GHCR moving-alias safety selector."""

import importlib.util
import pathlib
import unittest

FILE = pathlib.Path(__file__).with_name("release_aliases.py")
spec = importlib.util.spec_from_file_location("release_aliases", FILE)
release_aliases = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_aliases)


class ReleaseAliasTests(unittest.TestCase):
    def test_latest_stable_updates_all_matching_aliases(self):
        self.assertEqual(
            release_aliases.moving_aliases("v0.2.42", ["v0.2.41", "v0.2.42"]),
            ["v0.2", "v0", "latest"],
        )

    def test_old_patch_cannot_roll_back_moving_aliases(self):
        self.assertEqual(
            release_aliases.moving_aliases("v0.2.41", ["v0.2.41", "v0.2.42"]), [],
        )

    def test_old_minor_may_update_only_its_minor_alias(self):
        self.assertEqual(
            release_aliases.moving_aliases("v0.2.42", ["v0.2.42", "v0.3.1"]),
            ["v0.2"],
        )

    def test_old_major_may_update_its_own_aliases(self):
        self.assertEqual(
            release_aliases.moving_aliases("v1.2.0", ["v1.2.0", "v2.0.0"]),
            ["v1.2", "v1"],
        )

    def test_numeric_version_ordering(self):
        self.assertEqual(
            release_aliases.moving_aliases("v0.2.9", ["v0.2.9", "v0.2.10"]), [],
        )

    def test_prerelease_test_and_malformed_tags_never_move_aliases(self):
        for tag in ("v0.2.43-rc.1", "v0.2.43-beta.1", "v0.2.43-alpha.1", "test-5", "v01.2.3", "v0.2.3.4"):
            with self.subTest(tag=tag):
                self.assertEqual(release_aliases.moving_aliases(tag, [tag]), [])

    def test_missing_remote_tag_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "absent"):
            release_aliases.moving_aliases("v0.2.43", ["v0.2.42"])

    def test_remote_refs_ignore_annotated_dereferences(self):
        self.assertEqual(
            release_aliases.tags_from_ls_remote(
                "abc\trefs/tags/v0.2.41\n"
                "def\trefs/tags/v0.2.42\n"
                "ghi\trefs/tags/v0.2.42^{}\n"
            ),
            ["v0.2.41", "v0.2.42"],
        )

    def test_unexpected_remote_output_fails_closed(self):
        with self.assertRaises(ValueError):
            release_aliases.tags_from_ls_remote("invalid\n")


if __name__ == "__main__":
    unittest.main()
