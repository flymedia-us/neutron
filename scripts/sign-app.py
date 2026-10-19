#!/usr/bin/env python3
"""Sign nested Mach-O code before its containing app; verify the selected team."""

import argparse
import pathlib
import re
import subprocess
import sys


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def team_identity(team, distribution=False):
    identities = run("security", "find-identity", "-v", "-p", "codesigning")
    candidates = re.findall(r'([A-Fa-f0-9]{40}) "([^"]+)"', identities)
    # Prefer a distribution certificate when installed, otherwise use development.
    candidates.sort(key=lambda pair: not pair[1].startswith("Developer ID Application:"))
    for identity, name in candidates:
        if distribution and not name.startswith("Developer ID Application:"):
            continue
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
    parser.add_argument("--distribution", action="store_true",
                        help="Require Developer ID Application signing with hardened runtime.")
    args = parser.parse_args()
    identity = args.identity
    if identity == "auto":
        identity = team_identity(args.team, args.distribution)
        if identity is None:
            if args.require_team == "1" or args.distribution:
                sys.exit(f"No usable signing identity for Fly Media team {args.team}.")
            identity = "-"
            print("No Fly Media identity available; producing an ad hoc development build.")
    if identity == "-" and (args.require_team == "1" or args.distribution):
        sys.exit("A Fly Media build requires an Apple certificate, not ad hoc signing.")
    app = args.app.resolve(strict=True)
    binaries = []
    for path in sorted(app.rglob("*")):
        if path.is_file() and not path.is_symlink():
            if run("file", "-b", str(path)).startswith("Mach-O"):
                binaries.append(path)
    if not binaries:
        sys.exit("No Mach-O code found in the app bundle.")
    flags = ["--force", "--sign", identity, "--preserve-metadata=entitlements"]
    if identity != "-":
        flags += ["--options", "runtime", "--timestamp"]
    # Do not use codesign --deep to sign: it can silently miss or alter nested code.
    for binary in binaries:
        subprocess.run(["codesign", *flags, str(binary)], check=True)
    # Sign the actual helper bundles as well as their binaries, inside out.
    # Sparkle's XPC services and Updater.app each have their own resource seal.
    bundles = [path for path in app.rglob("*") if path.is_dir() and not path.is_symlink()
               and path.suffix in {".app", ".xpc", ".framework", ".bundle"}]
    bundles.sort(key=lambda path: len(path.parts), reverse=True)
    for bundle in bundles:
        # SwiftPM resource bundles contain no executable code.
        if any(binary.is_relative_to(bundle) for binary in binaries):
            subprocess.run(["codesign", *flags, str(bundle)], check=True)
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
        if args.distribution and "Authority=Developer ID Application:" not in result.stderr:
            sys.exit(f"{path.name} does not carry a Developer ID Application signature.")
        if args.distribution and not re.search(r"flags=.*\(.*runtime.*\)", result.stderr):
            sys.exit(f"{path.name} does not have hardened runtime enabled.")
    print(f"Signed and verified {len(binaries)} Mach-O files and {app.name}; "
          f"team {args.team if identity != '-' else 'ad hoc'}.")


if __name__ == "__main__":
    main()
