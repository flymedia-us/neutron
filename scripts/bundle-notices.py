#!/usr/bin/env python3
"""Include original licenses, copyright headers and exact source references."""

import argparse
import json
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=pathlib.Path)
    parser.add_argument("--highball", type=pathlib.Path, required=True)
    parser.add_argument("--dobby", type=pathlib.Path, required=True)
    args = parser.parse_args()
    sources = {
        "LICENSE": pathlib.Path("LICENSE"),
        "NOTICE": pathlib.Path("NOTICE"),
        "THIRD_PARTY_NOTICES.md": pathlib.Path("THIRD_PARTY_NOTICES.md"),
        "LICENSE.fonts": pathlib.Path("LICENSE.fonts"),
        "LICENSE.lsteamclient": pathlib.Path("LICENSE.lsteamclient"),
        "LICENSE.steam-shim": pathlib.Path("LICENSE.steam-shim"),
        "steam-shim/LICENSE": pathlib.Path("steam-shim/LICENSE"),
        "lsteamclient/LICENSE": pathlib.Path("lsteamclient/LICENSE"),
        "Wine/LICENSE": pathlib.Path("scratch/wine/LICENSE"),
        "Wine/COPYING.LIB": pathlib.Path("scratch/wine/COPYING.LIB"),
        "Wine/AUTHORS": pathlib.Path("scratch/wine/AUTHORS"),
        "OpenVR/LICENSE": pathlib.Path("third_party/openvr/LICENSE"),
        "OpenVR/SOURCE.json": pathlib.Path("third_party/openvr/SOURCE.json"),
        "Highball/LICENSE": args.highball / "LICENSE",
        "Dobby/LICENSE": args.dobby / "LICENSE",
        "highball-db/LICENSE": pathlib.Path("third_party/highball-db/LICENSE"),
        # Preserve notices in single-file dependencies verbatim with their sources.
        "JsonCpp/jsoncpp.cpp": pathlib.Path("steam-shim/jsoncpp.cpp"),
        "JsonCpp/json.h": pathlib.Path("steam-shim/json/json.h"),
        "JsonCpp/json-forwards.h": pathlib.Path("steam-shim/json/json-forwards.h"),
        "cJSON/cJSON.c": pathlib.Path("vendor/cJSON.c"),
        "cJSON/cJSON.h": pathlib.Path("vendor/cJSON.h"),
    }
    for relative, source in sources.items():
        target = args.destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], text=True).strip())
    (args.destination / "SOURCE.json").write_text(json.dumps({
        "repository": "https://github.com/flymedia-us/neutron",
        "revision": revision,
        "uncommitted_changes": dirty,
        "swift_packages": json.loads(pathlib.Path("app/Package.resolved").read_text()),
        "source": f"https://github.com/flymedia-us/neutron/tree/{revision}",
        "build_instructions": "README.md",
        "upstreams": json.loads(pathlib.Path("UPSTREAMS.json").read_text()),
    }, indent=2) + "\n")
    print(f"Bundled {len(sources)} original notices and source references.")


if __name__ == "__main__":
    main()
