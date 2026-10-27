#!/usr/bin/env python3
"""module.json lane_image: optional per-module image, operator override wins, default untouched."""
import json
import os
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import server  # noqa: E402


class LaneImage(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.old = server.SKILLS_DIR
        server.SKILLS_DIR = self.tmp.name
        self.saved = {k: os.environ.pop(k, None) for k in ("OMICSTAT_IMAGE", "OMICSTAT_PY_IMAGE")}

    def tearDown(self):
        server.SKILLS_DIR = self.old
        for k, v in self.saved.items():
            if v is not None:
                os.environ[k] = v
        self.tmp.cleanup()

    def module(self, name, **fields):
        folder = pathlib.Path(self.tmp.name) / name
        folder.mkdir()
        (folder / "module.json").write_text(json.dumps(dict(name=name, **fields)))

    def test_absent_field_keeps_the_current_lane_image(self):
        self.module("abc-plain")
        self.assertIsNone(server._lane_image("abc-plain"))
        self.assertEqual(server._image_name("abc-plain"), server._image_name())
        self.assertEqual(server._py_image_name("abc-plain"), server._py_image_name())

    def test_declared_r_image_is_used(self):
        self.module("abc-plug", lane_image="omicstat-abc:20261101")
        self.assertEqual(server._lane_image("abc-plug"), "omicstat-abc:20261101")
        self.assertEqual(server._image_name("abc-plug"), "omicstat-abc:20261101")
        self.assertEqual(server._py_image_name("abc-plug"), server._py_image_name())

    def test_declared_python_image_is_used_for_the_python_lane(self):
        self.module("abc-py", lane_image="omicstat-py-abc:20261101")
        self.assertEqual(server._py_image_name("abc-py"), "omicstat-py-abc:20261101")
        self.assertEqual(server._image_name("abc-py"), server._image_name())

    def test_operator_override_wins(self):
        self.module("abc-plug", lane_image="omicstat-abc:20261101")
        os.environ["OMICSTAT_IMAGE"] = "omicstat-r:operator"
        self.assertEqual(server._image_name("abc-plug"), "omicstat-r:operator")

    def test_malformed_or_unknown_values_are_ignored(self):
        for value in ("evil/image:latest", "omicstat-r", 7, "omicstat-r:1 --privileged"):
            self.module("abc-bad", lane_image=value)
            self.assertIsNone(server._lane_image("abc-bad"))
            (pathlib.Path(self.tmp.name) / "abc-bad" / "module.json").unlink()
            (pathlib.Path(self.tmp.name) / "abc-bad").rmdir()
        self.assertIsNone(server._lane_image("../../etc"))
        self.assertIsNone(server._lane_image("nomodule-here"))


if __name__ == "__main__":
    unittest.main()
