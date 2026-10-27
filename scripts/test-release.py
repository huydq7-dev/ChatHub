import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("validate_release", Path(__file__).with_name("validate-release.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseValidationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.project = self.root / "project.yml"
        self.project.write_text('MARKETING_VERSION: "0.3.0"\nCURRENT_PROJECT_VERSION: "3"\n')

    def test_matching_stable_tag(self):
        self.assertEqual(module.validate(self.project, "v0.3.0"), "0.3.0")

    def test_mismatched_or_non_stable_tags_fail(self):
        for tag in ["v0.2.0", "v0.3.0-beta", "v00.3.0", "main", "v0.3.0\nother"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                module.validate(self.project, tag)

    def test_stale_generated_xcode_project_cannot_publish_wrong_version(self):
        app = self.root / "ChatHub.app"
        (app / "Contents").mkdir(parents=True)
        info = app / "Contents/Info.plist"
        info.write_bytes(plistlib.dumps({"CFBundleShortVersionString": "0.2.0", "CFBundleVersion": "2"}))
        with self.assertRaises(ValueError):
            module.validate(self.project, app=app)
        info.write_bytes(plistlib.dumps({"CFBundleShortVersionString": "0.3.0", "CFBundleVersion": "3"}))
        self.assertEqual(module.validate(self.project, app=app), "0.3.0")


if __name__ == "__main__":
    unittest.main()
