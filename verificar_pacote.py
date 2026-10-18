"""Verify a frozen publication bundle using only Python's standard library."""
import hashlib
import json
from pathlib import Path


def verify(root):
    root = Path(root).resolve()
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != "enso-public-bundle-v1" or not manifest.get("files"):
        raise ValueError("Unknown or empty manifest")
    seen = set()
    for row in manifest["files"]:
        name = row["path"]
        path = (root / name).resolve()
        if name in seen or not path.is_relative_to(root) or path == root / "manifest.json":
            raise ValueError(f"Unsafe or duplicate entry: {name}")
        seen.add(name)
        if path.stat().st_size != row["bytes"] or hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError(f"Changed file: {name}")
    return len(seen)


if __name__ == "__main__":
    print(f"PASS: {verify(Path(__file__).resolve().parent)} manifest files match.")
