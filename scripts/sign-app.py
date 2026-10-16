#!/usr/bin/env python3
"""Sign nested Mach-O code before its containing app; verify the selected team."""

import argparse
import pathlib
import re
import subprocess
import sys


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def team_identity(team):
    identities = run("security", "find-identity", "-v", "-p", "codesigning")
    candidates = re.findall(r'([A-Fa-f0-9]{40}) "([^"]+)"', identities)
    # Prefer a distribution certificate when installed, otherwise use development.
    candidates.sort(key=lambda pair: not pair[1].startswith("Developer ID Application:"))
    for identity, name in candidates:
        certificate = run("security", "find-certificate", "-c", name, "-p")
        subject = subprocess.run(
            ["openssl", "x509", "-noout", "-subject", "-nameopt", "RFC2253"],
            input=certificate, text=True, check=True, capture_output=True,
        ).stdout
        if re.search(r"(?:^|,)OU=" + re.escape(team) + r"(?:,|$)", subject.strip()):
            return identity
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=pathlib.Path)
    parser.add_argument("--identity", default="auto")
    parser.add_argument("--team", default="BJZSH247Q9")
    parser.add_argument("--require-team", choices=["0", "1"], default="0")
    args = parser.parse_args()
    identity = args.identity
    if identity == "auto":
        identity = team_identity(args.team)
        if identity is None:
            if args.require_team == "1":
                sys.exit(f"No usable signing identity for Fly Media team {args.team}.")
            identity = "-"
            print("No Fly Media identity available; producing an ad hoc development build.")
    if identity == "-" and args.require_team == "1":
        sys.exit("A Fly Media build requires an Apple certificate, not ad hoc signing.")
    app = args.app.resolve(strict=True)
    binaries = []
    for path in sorted(app.rglob("*")):
        if path.is_file() and not path.is_symlink():
            if run("file", "-b", str(path)).startswith("Mach-O"):
                binaries.append(path)
    if not binaries:
        sys.exit("No Mach-O code found in the app bundle.")
    flags = ["--force", "--sign", identity]
    if identity != "-":
        flags += ["--options", "runtime", "--timestamp"]
    # Do not use codesign --deep to sign: it can silently miss or alter nested code.
    for binary in binaries:
        subprocess.run(["codesign", *flags, str(binary)], check=True)
    subprocess.run(["codesign", *flags, str(app)], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    for path in [*binaries, app]:
        if identity == "-":
            continue
        result = subprocess.run(
            ["codesign", "-d", "--verbose=4", str(path)], capture_output=True, text=True, check=True,
        )
        if f"TeamIdentifier={args.team}" not in result.stderr.splitlines():
            sys.exit(f"Unexpected signing team for {path.name}; expected {args.team}.")
    print(f"Signed and verified {len(binaries)} Mach-O files and {app.name}; "
          f"team {args.team if identity != '-' else 'ad hoc'}.")


if __name__ == "__main__":
    main()
