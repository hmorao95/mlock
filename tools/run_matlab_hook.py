#!/usr/bin/env python3
"""pre-commit helper: run mlock checks through a locally installed MATLAB.

Modes:
  --mode test   Run the unit tests (runtests('tests')); fails on any failure.
  --mode lint   Advisory Code Analyzer report on the given .m files; never fails.

If MATLAB is not found on PATH the hook prints a note and exits 0, so
contributors without MATLAB can still commit. CI is the authoritative gate.
"""
import argparse
import os
import shutil
import subprocess
import sys


def find_matlab():
    return shutil.which("matlab")


def run_matlab(repo_root, code):
    matlab = find_matlab()
    if not matlab:
        print("matlab not found on PATH; skipping MATLAB hook.")
        return 0
    cmd = [matlab, "-batch", code]
    print("+", matlab, "-batch", repr(code), flush=True)
    return subprocess.run(cmd, cwd=repo_root).returncode


def mode_test(repo_root, _files):
    code = (
        "results = runtests('tests');"
        " disp(results);"
        " failed = nnz([results.Failed]);"
        " if isempty(results) || failed > 0;"
        "   error('mlock:precommit', '%d test(s) failed', failed);"
        " end"
    )
    return run_matlab(repo_root, code)


def mode_lint(repo_root, files):
    m_files = [f for f in files if f.endswith(".m")]
    if not m_files:
        return 0
    joined = ";".join(f.replace("\\", "/") for f in m_files)
    code = (
        "files = strsplit('" + joined + "', ';'); n = 0;"
        " for i = 1:numel(files);"
        "   msgs = checkcode(files{i});"
        "   for k = 1:numel(msgs);"
        "     fprintf('%s:%d: %s\\n', files{i}, msgs(k).line, msgs(k).message);"
        "     n = n + 1;"
        "   end;"
        " end;"
        " fprintf('checkcode: %d message(s) (advisory).\\n', n);"
    )
    # Advisory: report but never fail the commit.
    run_matlab(repo_root, code)
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["test", "lint"], required=True)
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if args.mode == "test":
        return mode_test(repo_root, args.files)
    return mode_lint(repo_root, args.files)


if __name__ == "__main__":
    sys.exit(main())
