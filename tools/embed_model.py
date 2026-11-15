#!/usr/bin/env python3
import argparse
import os
import pathlib
import shutil
import zipfile

zipfile.ZIP64_LIMIT = 0xFFFFFFFF

SIGN_PREFIXES = ("META-INF/",)
SIGN_SUFFIXES = (".SF", ".RSA", ".DSA", ".EC")


def skip_entry(name):
    if name.endswith("/"):
        return False
    if not name.startswith(SIGN_PREFIXES):
        return False
    return name.upper().endswith(SIGN_SUFFIXES) or name.upper().endswith("MANIFEST.MF")


def add_file(zout, source, arcname, stored=False):
    info = zipfile.ZipInfo.from_file(source, arcname)
    info.compress_type = zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    with open(source, "rb") as src, zout.open(info, "w") as dst:
        shutil.copyfileobj(src, dst, 1024 * 1024)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("apk")
    parser.add_argument("--model", default="models/qwen2.5-3b-instruct-q4_k_m.gguf")
    parser.add_argument("--libs", default="")
    parser.add_argument("--worlds", default="worlds")
    parser.add_argument("--out", default="")
    args = parser.parse_args()

    apk = pathlib.Path(args.apk)
    out = pathlib.Path(args.out) if args.out else apk.with_name(apk.stem + "-full.apk")
    model = pathlib.Path(args.model)
    if not apk.exists() or not model.exists():
        raise SystemExit("APK or model not found")

    extras = []
    worlds = pathlib.Path(args.worlds)
    if worlds.is_dir():
        for path in sorted(worlds.rglob("*")):
            if path.is_file() and path.suffix.lower() in (".md", ".json") and path.name != "world.json":
                extras.append((path, "assets/" + path.as_posix(), True))
    if args.libs:
        libs = pathlib.Path(args.libs)
        for path in sorted(libs.glob("*.so")):
            extras.append((path, "lib/arm64-v8a/" + path.name, True))

    extras.append((model, "assets/models/" + model.name, True))

    with zipfile.ZipFile(apk, "r") as zin, zipfile.ZipFile(out, "w", allowZip64=True) as zout:
        replace = {arc for _, arc, _ in extras}
        for info in zin.infolist():
            if info.filename in replace or skip_entry(info.filename):
                continue
            with zin.open(info, "r") as src:
                out_info = zipfile.ZipInfo(info.filename, info.date_time)
                out_info.compress_type = info.compress_type
                out_info.external_attr = info.external_attr
                out_info.internal_attr = info.internal_attr
                out_info.create_system = info.create_system
                with zout.open(out_info, "w") as dst:
                    shutil.copyfileobj(src, dst, 1024 * 1024)
        for source, arc, stored in extras:
            add_file(zout, source, arc, stored)

    print("OK", out, out.stat().st_size)
    for source, arc, _ in extras:
        print(" ", arc, source.stat().st_size)


if __name__ == "__main__":
    main()
