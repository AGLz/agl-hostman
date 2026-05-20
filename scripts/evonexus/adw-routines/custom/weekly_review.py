#!/usr/bin/env python3
"""Wrapper: weekly_review do core (scheduler procura em custom/)."""

import os
import subprocess
import sys

_parent = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
raise SystemExit(
    subprocess.call(
        [sys.executable, os.path.join(_parent, "weekly_review.py"), *sys.argv[1:]],
        cwd=_parent,
    )
)
