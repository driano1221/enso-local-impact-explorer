import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import requests
from stellar_sdk import Account, Keypair, TransactionBuilder

import verificar as v


class IntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.file = self.root / "climate.csv"
        self.file.write_bytes(b"temperature\n23.0\n")
        self.manifest = self.root / "manifest.json"
        self.manifest.write_text(json.dumps({"schema": "enso-public-bundle-v1", "files": [
            {"path": self.file.name, "bytes": self.file.stat().st_size,
             "sha256": v.sha256(self.file)}]}))
        self.digest = v.check_bundle(self.manifest)
        self.key = Keypair.random()
        self.envelope = (TransactionBuilder(Account(self.key.public_key, 0),
                        network_passphrase=v.PASSPHRASE, base_fee=100)
                        .add_hash_memo(self.digest)
                        .append_manage_data_op(v.DATA_NAME, bytes.fromhex(self.digest))
                        .set_timeout(180).build())
        self.envelope.sign(self.key)
        self.txid = self.envelope.hash_hex()
        self.tx = {"hash": self.txid, "successful": True, "ledger": 123,
                   "source_account": self.key.public_key, "memo_type": "hash",
                   "memo": base64.b64encode(bytes.fromhex(self.digest)).decode(),
                   "envelope_xdr": self.envelope.to_xdr(), "created_at": "fixture"}

    def check(self, tx=None, digest=None, account=None):
        return v.check_transaction(tx or self.tx, digest or self.digest, self.txid,
                                   account or self.key.public_key)

    def test_original(self):
        self.assertTrue(self.check()["valid"])

    def test_one_byte_changed(self):
        self.file.write_bytes(self.file.read_bytes().replace(b"23.0", b"24.0"))
        with self.assertRaisesRegex(ValueError, "File changed"):
            v.check_bundle(self.manifest)

    def test_rewritten_manifest_still_fails_anchor(self):
        with self.assertRaisesRegex(ValueError, "Digest differs"):
            self.check(digest=hashlib.sha256(b"another manifest").hexdigest())

    def test_wrong_network(self):
        with self.assertRaisesRegex(ValueError, "Wrong network"):
            v.check_network({"network_passphrase": "Public Global Stellar Network ; September 2015"})

    def test_wrong_account(self):
        with self.assertRaises(ValueError):
            self.check(account=Keypair.random().public_key)

    def test_failed_unconfirmed_and_wrong_id(self):
        for key, value in [("successful", False), ("ledger", 0), ("hash", "0" * 64)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check(tx={**self.tx, key: value})

    def test_tampered_signature(self):
        self.envelope.signatures[0].signature = b"x" * 64
        with self.assertRaises(Exception):
            self.check(tx={**self.tx, "envelope_xdr": self.envelope.to_xdr()})

    def test_wrong_operation(self):
        self.envelope.transaction.operations[0].data_name = "different"
        with self.assertRaises(ValueError):
            self.check(tx={**self.tx, "envelope_xdr": self.envelope.to_xdr()})

    def test_path_escape(self):
        body = json.loads(self.manifest.read_text())
        body["files"][0]["path"] = "../outside.csv"
        self.manifest.write_text(json.dumps(body))
        with self.assertRaisesRegex(ValueError, "Unsafe bundle path"):
            v.check_bundle(self.manifest)

    def test_network_failure_and_missing_transaction(self):
        for error in [requests.Timeout("offline"), requests.HTTPError("404")]:
            with patch.object(v, "get_json", side_effect=[
                    {"network_passphrase": v.PASSPHRASE}, error]):
                with self.assertRaises(type(error)):
                    v.verify(self.manifest, self.txid, self.key.public_key)

    def test_no_receipt_overwrite(self):
        with self.assertRaises(FileExistsError):
            v.save(self.manifest, {})

    def test_pending_blocks_duplicate_anchor_before_network(self):
        receipt = self.root / "receipt.json"
        v.save(receipt.with_suffix(".pending.json"), {})
        with patch.object(v, "get_json") as network:
            with self.assertRaisesRegex(ValueError, "pending transaction exists"):
                v.anchor(self.manifest, receipt)
            network.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
