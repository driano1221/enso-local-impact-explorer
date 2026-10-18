"""Read-only integration check against the published demo transaction."""
import json
from pathlib import Path
import shutil
import tempfile
from datetime import datetime, timezone

import requests
import verificar as v

ROOT = Path(__file__).resolve().parent
TX = "b8c1c116925fa4e2f6affcbe544d91d0f408275ca022a26f848b875098102a26"
ACCOUNT = "GCVEOSSRF2CMDYBANGWIY5NMPU6NUR2M6WAJ5NTCKGEUNI7RWAJIJIZE"


def run():
    result, tx = v.verify(ROOT / "demo/manifest.json", TX, ACCOUNT)
    ledger = v.get_json(f"{v.HORIZON}/ledgers/{result['ledger']}")
    assert ledger["closed_at"] == result["closed_at"]
    operations = v.get_json(f"{v.HORIZON}/transactions/{TX}/operations")["_embedded"]["records"]
    assert len(operations) == 1 and operations[0]["type"] == "manage_data"
    assert operations[0]["name"] == v.DATA_NAME and operations[0]["value"] == tx["memo"]
    with tempfile.TemporaryDirectory() as folder:
        target = Path(folder) / "demo"
        shutil.copytree(ROOT / "demo", target)
        csv = target / "vicosa_son_chart_en.csv"
        data = csv.read_bytes()
        assert b"20.702078853046594" in data
        csv.write_bytes(data.replace(b"20.702078853046594", b"21.702078853046594", 1))
        try:
            v.check_bundle(target / "manifest.json")
        except ValueError as error:
            changed = str(error)
        else:
            raise AssertionError("Changed CSV was accepted")
        manifest = target / "manifest.json"
        body = json.loads(manifest.read_text(encoding="utf-8"))
        body["files"][0]["sha256"] = v.sha256(csv)
        manifest.write_text(json.dumps(body), encoding="utf-8")
        try:
            v.check_transaction(tx, v.check_bundle(manifest), TX, ACCOUNT)
        except ValueError as error:
            rewritten = str(error)
        else:
            raise AssertionError("Rewritten manifest was accepted")
    try:
        v.get_json(f"{v.HORIZON}/transactions/{'0' * 64}")
    except requests.HTTPError as error:
        assert error.response.status_code == 404
    else:
        raise AssertionError("Missing transaction was accepted")
    result.update({"checked_at_utc": datetime.now(timezone.utc).isoformat(),
                   "ledger_hash": ledger["hash"], "original": "PASS",
                   "one_byte_change_rejected": changed,
                   "rewritten_manifest_rejected": rewritten, "missing_transaction": "HTTP 404",
                   "manage_data_independently_checked": True})
    (ROOT / "demo/live_check.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    run()
