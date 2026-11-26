import subprocess
import tempfile
import unittest
from pathlib import Path

from checks.files import EXCLUDED, Language, language_of, select
from checks.repo import AddedLine, GitError, GitRepo, Scope


class FakeGit:
    def __init__(self, tracked=b"", untracked=b"", everything=b"", patch=b"", base=None, fail=None):
        self.outputs = {
            "names": tracked,
            "others": untracked,
            "all": everything,
            "patch": patch,
        }
        self.base = base
        self.fail = fail
        self.calls = []

    def __call__(self, argv, cwd):
        self.calls.append(argv)
        kind = self.kind_of(argv)
        if kind == self.fail:
            return subprocess.CompletedProcess(argv, 128, b"", b"fatal: broken\n")
        if kind == "rev-parse":
            if self.base is None:
                return subprocess.CompletedProcess(argv, 128, b"", b"")
            return subprocess.CompletedProcess(argv, 0, self.base + b"\n", b"")
        return subprocess.CompletedProcess(argv, 0, self.outputs[kind], b"")

    @staticmethod
    def kind_of(argv):
        assert argv[0] == "git", argv
        if "rev-parse" in argv:
            return "rev-parse"
        if "ls-files" in argv:
            assert "-z" in argv and "--exclude-standard" in argv and "--others" in argv, argv
            return "all" if "--cached" in argv else "others"
        assert "diff" in argv, argv
        if "--name-only" in argv:
            assert "-z" in argv, argv
            return "names"
        return "patch"

    def call_of(self, kind):
        matches = [argv for argv in self.calls if self.kind_of(argv) == kind]
        assert len(matches) == 1, self.calls
        return matches[0]


def nul(*paths):
    return b"".join(path.encode() + b"\0" for path in paths)


class TreeTestCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def write(self, path, content="x\n"):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content.encode() if isinstance(content, str) else content)

    def selected(self, git, scope=Scope.CHANGED):
        return select(GitRepo(self.root, git).paths(scope), self.root)

    @staticmethod
    def flat(selection):
        return sorted(path for paths in selection.values() for path in paths)


class SelectionTests(TreeTestCase):
    def test_deleted_path_is_dropped(self):
        self.write("Sources/Kept.swift")
        git = FakeGit(tracked=nul("Sources/Gone.swift", "Sources/Kept.swift"))
        self.assertEqual(self.flat(self.selected(git)), ["Sources/Kept.swift"])

    def test_renamed_file_appears_once_under_new_name(self):
        self.write("Sources/New.swift")
        git = FakeGit(tracked=nul("Sources/Old.swift", "Sources/New.swift"))
        self.assertEqual(self.flat(self.selected(git)), ["Sources/New.swift"])
        self.assertIn("--no-renames", git.call_of("names"))

    def test_case_only_rename_appears_once_under_new_name(self):
        self.write("Sources/Url.swift")
        git = FakeGit(tracked=nul("Sources/URL.swift", "Sources/Url.swift"))
        self.assertEqual(self.flat(self.selected(git)), ["Sources/Url.swift"])

    def test_name_that_differs_only_in_unicode_form_is_kept(self):
        self.write("Sources/Café.swift")
        selection = select(["Sources/Café.swift"], self.root)
        self.assertEqual(len(selection[Language.SWIFT]), 1)

    def test_path_with_spaces_survives(self):
        self.write("Sources/A B.swift")
        git = FakeGit(tracked=nul("Sources/A B.swift"))
        self.assertEqual(self.selected(git)[Language.SWIFT], ["Sources/A B.swift"])

    def test_path_with_newline_survives(self):
        self.write("Sources/A\nB.swift")
        git = FakeGit(tracked=nul("Sources/A\nB.swift"))
        self.assertEqual(self.selected(git)[Language.SWIFT], ["Sources/A\nB.swift"])

    def test_untracked_file_in_new_directory_is_selected(self):
        self.write("brand/new/tool.py")
        git = FakeGit(untracked=nul("brand/new/tool.py"))
        self.assertEqual(self.selected(git)[Language.PYTHON], ["brand/new/tool.py"])

    def test_excluded_paths_are_dropped(self):
        dropped = [
            "scripts/create-dmg",
            "scripts/support/x",
            "scripts/support/deep/x.sh",
            "MediaGrabber.xcodeproj/x.yml",
            "MediaGrabber.xcworkspace/x.yml",
            "Derived/Sources/X.swift",
            "Tuist/Derived/X.swift",
            ".build/x.swift",
            "build/logs/x.py",
            "a.xcuserstate",
            "x/xcuserdata/x.yml",
            "MediaGrabber.dmg",
            "SHA256SUMS",
            ".sparkle-private-key",
            "Resources/Tools/x.py",
            "Resources/Shield/server/build/main.sh",
            "Resources/Licenses/x.yml",
            ".venv/lib/x.py",
            ".ruff_cache/x.toml",
            ".pytest_cache/x.py",
            "scripts/checks/__pycache__/x.py",
            "__pycache__/x.py",
            ".playwright-mcp/page.yml",
        ]
        for path in dropped:
            self.write(path)
        self.assertEqual(self.flat(select(dropped, self.root)), [])

    def test_look_alikes_of_excluded_paths_are_kept(self):
        kept = [
            "scripts/create-dmg.sh",
            "scripts/supporting/x.sh",
            "scripts/buildlog/runner.py",
            "scripts/build",
            "docs/SHA256SUMS",
            "Tests/Resources/Tools/x.py",
        ]
        for path in kept:
            self.write(path)
        self.assertEqual(self.flat(select(kept, self.root)), sorted(kept))

    def test_excluded_names_the_vendored_script_and_its_support_files(self):
        self.assertIn("scripts/create-dmg", EXCLUDED)
        self.assertIn("scripts/support/", EXCLUDED)

    def test_change_to_only_excluded_files_selects_nothing(self):
        self.write("scripts/create-dmg", "#!/usr/bin/env bash\n")
        git = FakeGit(tracked=nul("scripts/create-dmg"))
        self.assertEqual(self.flat(self.selected(git)), [])

    def test_extensionless_shell_by_shebang(self):
        self.write("scripts/tests/stubs/gh", "#!/usr/bin/env bash\necho hi\n")
        selection = select(["scripts/tests/stubs/gh"], self.root)
        self.assertEqual(selection[Language.SHELL], ["scripts/tests/stubs/gh"])

    def test_root_and_scripts_swift_are_swift(self):
        for path in ("Project.swift", "scripts/ed25519.swift"):
            self.write(path, "#!/usr/bin/env swift\n")
        selection = select(["Project.swift", "scripts/ed25519.swift"], self.root)
        self.assertEqual(selection[Language.SWIFT], ["Project.swift", "scripts/ed25519.swift"])

    def test_empty_language_has_empty_list(self):
        self.write("a.py")
        selection = select(["a.py"], self.root)
        self.assertEqual(set(selection), set(Language))
        self.assertEqual(selection[Language.SWIFT], [])
        self.assertEqual(selection[Language.SHELL], [])

    def test_repeated_path_is_listed_once_in_sorted_order(self):
        self.write("b.py")
        self.write("a.py")
        self.assertEqual(
            select(["b.py", "a.py", "b.py"], self.root)[Language.PYTHON], ["a.py", "b.py"]
        )

    def test_directories_and_symlinks_are_dropped(self):
        self.write("real.py")
        (self.root / "link.py").symlink_to("real.py")
        (self.root / "folder.py").mkdir()
        self.assertEqual(self.flat(select(["link.py", "folder.py"], self.root)), [])

    def test_binary_file_without_extension_is_other(self):
        self.write("blob", b"\xff\xfe\x00\x01" * 200)
        self.assertEqual(select(["blob"], self.root)[Language.OTHER], ["blob"])


class LanguageTests(unittest.TestCase):
    def assert_language(self, expected, *cases):
        for path, first_line in cases:
            with self.subTest(path=path, first_line=first_line):
                self.assertEqual(language_of(path, first_line), expected)

    def test_extensions(self):
        self.assert_language(Language.SWIFT, ("Sources/A.swift", ""))
        self.assert_language(Language.SHELL, ("a.sh", ""), ("a.bash", ""))
        self.assert_language(Language.PYTHON, ("a.py", ""))

    def test_config_is_yaml_toml_and_makefile(self):
        self.assert_language(
            Language.CONFIG,
            (".github/workflows/ci.yml", ""),
            ("a.yaml", ""),
            (".mise.toml", ""),
            ("Makefile", ""),
            ("sub/Makefile", ""),
        )

    def test_shell_shebangs(self):
        self.assert_language(
            Language.SHELL,
            ("gh", "#!/usr/bin/env bash\n"),
            ("gh", "#!/bin/bash"),
            ("gh", "#!/bin/sh -e"),
            ("gh", "#! /bin/sh"),
            ("gh", "#!/usr/bin/env -S bash -eu"),
            ("gh", "#!/usr/bin/env LC_ALL=C sh"),
        )

    def test_python_shebang(self):
        self.assert_language(
            Language.PYTHON,
            ("tool", "#!/usr/bin/env python3"),
            ("tool", "#!/opt/homebrew/bin/python3.15"),
        )

    def test_everything_else_is_other(self):
        self.assert_language(
            Language.OTHER,
            ("README.md", "# Title"),
            (".swiftformat", "--disable docComments"),
            ("tool", "#!/usr/bin/env node"),
            ("tool", "#!/usr/bin/env zsh"),
            ("tool", "#!"),
            ("tool", "#!/usr/bin/env"),
            ("tool", ""),
            ("notes", "bash is a shell"),
        )

    def test_known_extension_wins_over_shebang(self):
        self.assert_language(Language.SWIFT, ("a.swift", "#!/usr/bin/env bash"))


class GitPathTests(TreeTestCase):
    def test_changed_is_difference_from_last_commit_plus_untracked(self):
        git = FakeGit(tracked=nul("a.py"), untracked=nul("b.py"))
        self.assertEqual(GitRepo(self.root, git).paths(Scope.CHANGED), ["a.py", "b.py"])
        self.assertIn("HEAD", git.call_of("names"))
        self.assertNotIn("--cached", git.call_of("names"))

    def test_staged_reads_only_the_index(self):
        git = FakeGit(tracked=nul("a.py"))
        self.assertEqual(GitRepo(self.root, git).paths(Scope.STAGED), ["a.py"])
        self.assertIn("--cached", git.call_of("names"))
        self.assertEqual(len(git.calls), 1)

    def test_all_is_every_file_not_ignored_without_repeats(self):
        git = FakeGit(everything=nul("a.py", "conflict.py", "conflict.py"))
        self.assertEqual(GitRepo(self.root, git).paths(Scope.ALL), ["a.py", "conflict.py"])
        self.assertEqual(len(git.calls), 1)

    def test_no_changes_gives_no_paths(self):
        self.assertEqual(GitRepo(self.root, FakeGit()).paths(Scope.CHANGED), [])

    def test_failed_git_command_raises_instead_of_listing_nothing(self):
        for scope, kind in [
            (Scope.CHANGED, "names"),
            (Scope.CHANGED, "others"),
            (Scope.STAGED, "names"),
            (Scope.ALL, "all"),
        ]:
            with self.subTest(scope=scope, kind=kind):
                with self.assertRaisesRegex(GitError, "fatal: broken"):
                    GitRepo(self.root, FakeGit(fail=kind)).paths(scope)


PATCH = b"""diff --git a/a.py b/a.py
index 1111111..2222222 100644
--- a/a.py
+++ b/a.py
@@ -2,0 +3,2 @@ def f():
+first
+++ looks like a header
@@ -9 +11 @@
--- looks like a header too
+second
\\ No newline at end of file
diff --git a/gone.py b/gone.py
deleted file mode 100644
index 1111111..0000000
--- a/gone.py
+++ /dev/null
@@ -1,2 +0,0 @@
-one
-two
diff --git a/Sources/A B.swift b/Sources/A B.swift
index 1111111..2222222 100644
--- a/Sources/A B.swift\t
+++ b/Sources/A B.swift\t
@@ -0,0 +1 @@
+spaced\r
diff --git "a/q\\"uote\\t\\303\\251.py" "b/q\\"uote\\t\\303\\251.py"
index 1111111..2222222 100644
--- "a/q\\"uote\\t\\303\\251.py"
+++ "b/q\\"uote\\t\\303\\251.py"
@@ -1,0 +2 @@
+quoted \xc3\xa9\x0cstill one line \xff
diff --git a/old.py b/new.py
similarity index 100%
rename from old.py
rename to new.py
diff --git a/image.png b/image.png
Binary files a/image.png and b/image.png differ
"""


class AddedLineTests(TreeTestCase):
    def test_added_lines_carry_path_and_new_line_number(self):
        added = GitRepo(self.root, FakeGit(patch=PATCH)).added_lines(Scope.CHANGED)
        self.assertEqual(
            added,
            [
                AddedLine("a.py", 3, "first"),
                AddedLine("a.py", 4, "++ looks like a header"),
                AddedLine("a.py", 11, "second"),
                AddedLine("Sources/A B.swift", 1, "spaced"),
                AddedLine('q"uote\té.py', 2, "quoted é\x0cstill one line �"),
            ],
        )

    def test_context_lines_advance_the_line_number(self):
        patch = b"--- a/a.py\n+++ b/a.py\n@@ -1,2 +1,3 @@\n same\n+new\n same\n"
        added = GitRepo(self.root, FakeGit(patch=patch)).added_lines(Scope.CHANGED)
        self.assertEqual(added, [AddedLine("a.py", 2, "new")])

    def test_patch_command_does_not_depend_on_user_settings(self):
        git = FakeGit()
        GitRepo(self.root, git).added_lines(Scope.CHANGED)
        argv = git.call_of("patch")
        for flag in (
            "-U0",
            "--inter-hunk-context=0",
            "--no-color",
            "--no-ext-diff",
            "--no-textconv",
            "--no-relative",
            "--find-renames",
            "--src-prefix=a/",
            "--dst-prefix=b/",
            "HEAD",
        ):
            self.assertIn(flag, argv)

    def test_every_line_of_an_untracked_file_is_added(self):
        self.write("brand/new/tool.py", "one\r\n\nthree")
        git = FakeGit(untracked=nul("brand/new/tool.py"))
        self.assertEqual(
            GitRepo(self.root, git).added_lines(Scope.CHANGED),
            [
                AddedLine("brand/new/tool.py", 1, "one"),
                AddedLine("brand/new/tool.py", 2, ""),
                AddedLine("brand/new/tool.py", 3, "three"),
            ],
        )

    def test_untracked_binaries_links_and_missing_files_add_no_lines(self):
        self.write("cache.pyc", b"\x00\x01# noqa\n")
        self.write("real.txt", "text\n")
        (self.root / "link.txt").symlink_to("real.txt")
        git = FakeGit(untracked=nul("cache.pyc", "link.txt", "vanished.py"))
        self.assertEqual(GitRepo(self.root, git).added_lines(Scope.CHANGED), [])

    def test_staged_leaves_out_untracked_files(self):
        git = FakeGit()
        GitRepo(self.root, git).added_lines(Scope.STAGED)
        self.assertIn("--cached", git.call_of("patch"))
        self.assertNotIn("HEAD", git.call_of("patch"))
        self.assertEqual(len(git.calls), 1)

    def test_all_without_a_base_compares_with_the_last_commit(self):
        git = FakeGit()
        self.assertEqual(GitRepo(self.root, git).added_lines(Scope.ALL), [])
        self.assertIn("HEAD", git.call_of("patch"))

    def test_usable_base_is_resolved_then_compared(self):
        git = FakeGit(base=b"abc123")
        self.assertEqual(GitRepo(self.root, git).added_lines(Scope.ALL, "origin/main"), [])
        resolve = git.call_of("rev-parse")
        self.assertEqual(resolve[-2:], ["--end-of-options", "origin/main^{commit}"])
        self.assertIn("--verify", resolve)
        self.assertIn("abc123", git.call_of("patch"))
        self.assertNotIn("HEAD", git.call_of("patch"))

    def test_unusable_base_returns_none(self):
        for base in ("0" * 40, "no-such-ref", ""):
            with self.subTest(base=base):
                git = FakeGit(base=None)
                self.assertIsNone(GitRepo(self.root, git).added_lines(Scope.ALL, base))
                self.assertNotIn("patch", [git.kind_of(argv) for argv in git.calls])

    def test_failed_diff_raises_instead_of_reporting_nothing(self):
        for base in (None, "main"):
            with self.subTest(base=base):
                git = FakeGit(base=b"abc123", fail="patch")
                with self.assertRaisesRegex(GitError, "fatal: broken"):
                    GitRepo(self.root, git).added_lines(Scope.ALL, base)


class ChangedSinceTests(TreeTestCase):
    def test_paths_since_a_base_include_deleted_and_both_names_of_a_rename(self):
        git = FakeGit(
            tracked=nul("gone.py", "old name.py", "new name.py"),
            untracked=nul("fresh/added.py"),
            base=b"abc123",
        )
        found = GitRepo(self.root, git).changed_since(Scope.ALL, "main")
        self.assertEqual(found, ["gone.py", "old name.py", "new name.py", "fresh/added.py"])
        names = git.call_of("names")
        self.assertIn("abc123", names)
        self.assertIn("--no-renames", names)
        self.assertNotIn("--cached", names)
        self.assertIn("main^{commit}", git.call_of("rev-parse"))

    def test_staged_paths_since_a_base_read_only_the_index(self):
        git = FakeGit(tracked=nul("a.py"), untracked=nul("b.py"), base=b"abc123")
        self.assertEqual(GitRepo(self.root, git).changed_since(Scope.STAGED, "main"), ["a.py"])
        self.assertIn("--cached", git.call_of("names"))

    def test_unusable_base_gives_no_paths_and_compares_nothing(self):
        for base in ("nowhere", ""):
            with self.subTest(base=base):
                git = FakeGit()
                self.assertIsNone(GitRepo(self.root, git).changed_since(Scope.ALL, base))
                self.assertFalse([argv for argv in git.calls if "diff" in argv])


if __name__ == "__main__":
    unittest.main()
