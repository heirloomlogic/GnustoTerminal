#!/usr/bin/env python3
"""Exercise a built Zork1 terminal launcher: python3 Tests/terminal-pty.py BINARY."""
import fcntl
import os
import pty
import re
import select
import struct
import subprocess
import sys
import tempfile
import termios
import time
import unittest

BINARY = os.path.abspath(sys.argv.pop(1))
CSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z~]")


class TerminalInteractionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.master, self.slave = pty.openpty()
        self.original = termios.tcgetattr(self.slave)
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", 16, 60, 0, 0))
        env = dict(os.environ, TERM="xterm-256color", GNUSTO_SEED="0",
                   GNUSTO_SAVE_DIR=self.directory.name)
        for key in ("GNUSTO_PLAIN", "GNUSTO_MCP", "GNUSTO_TRANSCRIPT"):
            env.pop(key, None)
        self.process = subprocess.Popen([BINARY], stdin=self.slave, stdout=self.slave,
                                        stderr=self.slave, env=env)
        self.output = b""
        self.drain()

    def drain(self):
        deadline = time.monotonic() + 5
        quiet_since = None
        while time.monotonic() < deadline:
            if select.select([self.master], [], [], 0.03)[0]:
                self.output += os.read(self.master, 65536)
                quiet_since = time.monotonic()
            elif quiet_since is not None and time.monotonic() - quiet_since > 0.2:
                return

    def send(self, keys):
        self.output = b""
        os.write(self.master, keys)
        self.drain()

    def frame(self):
        frame = self.output.decode(errors="replace").split("\x1b[?25l")[-1]
        return CSI.sub("", frame)

    def live(self):
        self.send(b"\x1b[6~" * 20)

    def tearDown(self):
        try:
            if self.process.poll() is None:
                self.send(b"\x03y ")
            self.process.wait(timeout=3)
            self.assertEqual(self.process.returncode, 0)
            self.assertEqual(termios.tcgetattr(self.slave), self.original)
            self.assertIn(b"\x1b[?1049l", self.output)
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait()
            os.close(self.master)
            os.close(self.slave)
            self.directory.cleanup()

    def test_opening_starts_at_beginning(self):
        self.assertIn("An adventure awaits", self.frame())
        self.assertIn("-- more (PgDn) --", self.frame())

    def test_typing_returns_to_live_prompt(self):
        self.live()
        self.send(b"\x1b[5~")
        self.assertIn("-- more (PgDn) --", self.frame())
        self.send(b"l")
        self.assertNotIn("-- more (PgDn) --", self.frame())
        self.assertIn("> l", self.frame())

    def test_paste_returns_to_live_prompt(self):
        self.live()
        self.send(b"\x1b[5~")
        self.assertIn("-- more (PgDn) --", self.frame())
        self.send(b"\x1b[200~look\x1b[201~")
        self.assertNotIn("-- more (PgDn) --", self.frame())
        self.assertIn("> look", self.frame())

    def test_tab_extends_shared_prefix_without_leaving_suggestions(self):
        self.live()
        self.send(b"s")
        original = self.frame()
        self.send(b"\t\t\t")
        self.assertEqual(self.frame(), original)
        self.send(b"o\t")
        self.assertTrue(self.frame().endswith("> south"), self.frame())
        extended = self.frame()
        self.send(b"\t\t")
        self.assertEqual(self.frame(), extended)
        self.send(b"e\t")
        self.assertTrue(self.frame().endswith("> southeast "), self.frame())
        self.send(b"\x15loo\t")
        self.assertTrue(self.frame().endswith("> look "), self.frame())

    def test_mouse_scrolls_without_recalling_history(self):
        self.live()
        self.send(b"look\r")
        self.send(b"\x1b[<64;20;10M")
        self.assertIn("-- more (PgDn) --", self.frame())
        self.send(b"\x1b[<65;20;10M")
        self.assertNotIn("-- more (PgDn) --", self.frame())
        self.assertNotIn("> look", self.frame().split("There is a small mailbox here.")[-1])
        self.send(b"\x1b[A")
        self.assertIn("> look", self.frame())
        self.send(b"\x1b[B")
        self.assertTrue(self.frame().endswith("> "), self.frame())

    def check_prompt_cancellation(self, command, key):
        self.live()
        self.send(command + b"\r")
        self.send(b"unfinished")
        self.send(key)
        self.assertNotIn("Do you really want to quit?", self.frame())
        self.assertIn("Cancelled", self.frame())
        self.send(b"look\r")
        self.assertIn("West of House", self.frame())
        self.assertEqual([name for name in os.listdir(self.directory.name) if name != ".history"], [])

    def test_ctrl_c_cancels_save(self):
        self.check_prompt_cancellation(b"save", b"\x03")

    def test_escape_cancels_save(self):
        self.check_prompt_cancellation(b"save", b"\x1b")

    def test_escape_cancels_restore(self):
        self.check_prompt_cancellation(b"restore", b"\x1b")

    def test_ctrl_c_cancels_restore(self):
        self.check_prompt_cancellation(b"restore", b"\x03")

    def test_escape_cancels_quit_confirmation(self):
        self.live()
        self.send(b"\x03")
        self.assertIn("Do you really want to quit?", self.frame())
        self.send(b"\x1b")
        self.assertTrue(self.frame().endswith("> "), self.frame())
        self.send(b"look\r")
        self.assertIn("Moves: 1", self.frame())
        self.assertIsNone(self.process.poll())


if __name__ == "__main__":
    unittest.main()
