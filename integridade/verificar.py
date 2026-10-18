"""Anchor and verify public manifests on Stellar Testnet only; never uses real funds."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import sys

import requests
from stellar_sdk import Account, Keypair, Network, TransactionBuilder, TransactionEnvelope
from stellar_sdk.operation import ManageData

HORIZON = "https://horizon-testnet.stellar.org"
FRIENDBOT = "https://friendbot-testnet.stellar.org"
PASSPHRASE = Network.TESTNET_NETWORK_PASSPHRASE
DATA_NAME = "enso-manifest-sha256"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    # Exclusive creation prevents accidentally replacing a published receipt.
    with Path(path).open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False)
        stream.write("\n")


def get_json(url):
    response = requests.get(url, timeout=45)
    response.raise_for_status()
    return response.json()


def check_network(root):
    require(root.get("network_passphrase") == PASSPHRASE, "Wrong network: Testnet required")


def check_bundle(manifest):
    manifest = Path(manifest).resolve()
    bundle = json.loads(manifest.read_text(encoding="utf-8"))
    require(bundle.get("schema") == "enso-public-bundle-v1", "Unknown manifest schema")
    files = bundle.get("files", [])
    require(bool(files), "Empty manifest")
    seen = set()
    for item in files:
        name = item["path"]
        path = (manifest.parent / name).resolve()
        require(path.is_relative_to(manifest.parent) and path != manifest, "Unsafe bundle path")
        require(name not in seen, "Duplicate bundle entry")
        seen.add(name)
        require(path.stat().st_size == item["bytes"], f"Size differs: {name}")
        require(sha256(path) == item["sha256"], f"File changed: {name}")
    return sha256(manifest)


def check_transaction(tx, digest, txid, account):
    require(tx.get("successful") is True and int(tx.get("ledger", 0)) > 0,
            "Transaction is not confirmed and successful")
    require(tx.get("hash") == txid and tx.get("source_account") == account,
            "Transaction ID or public account differs")
    require(tx.get("memo_type") == "hash" and
            tx.get("memo") == base64.b64encode(bytes.fromhex(digest)).decode(), "Digest differs")
    envelope = TransactionEnvelope.from_xdr(tx["envelope_xdr"], PASSPHRASE)
    require(envelope.hash_hex() == txid, "Envelope hash/network differs")
    transaction = envelope.transaction
    require(transaction.source.account_id == account, "Envelope account differs")
    require(transaction.memo.memo_hash == bytes.fromhex(digest), "Envelope memo differs")
    require(len(transaction.operations) == 1, "Unexpected operations")
    operation = transaction.operations[0]
    require(isinstance(operation, ManageData) and operation.source is None and
            operation.data_name == DATA_NAME and operation.data_value == bytes.fromhex(digest),
            "Unexpected data operation")
    require(len(envelope.signatures) == 1, "Unexpected signature count")
    Keypair.from_public_key(account).verify(envelope.hash(), envelope.signatures[0].signature)
    return {"valid": True, "sha256": digest, "transaction": txid, "account": account,
            "ledger": tx["ledger"], "closed_at": tx["created_at"],
            "network": "Stellar Testnet", "network_id": Network(PASSPHRASE).network_id().hex(),
            "transaction_url": f"{HORIZON}/transactions/{txid}"}


def verify(manifest, txid, account):
    digest = check_bundle(manifest)
    check_network(get_json(HORIZON))
    tx = get_json(f"{HORIZON}/transactions/{txid}")
    result = check_transaction(tx, digest, txid, account)
    return result, tx


def anchor(manifest, receipt):
    digest = check_bundle(manifest)
    receipt = Path(receipt)
    pending = receipt.with_suffix(".pending.json")
    require(not receipt.exists() and not pending.exists(),
            "Receipt/pending transaction exists; verify its transaction before any new anchor")
    check_network(get_json(HORIZON))
    key = Keypair.random()  # Ephemeral secret: never serialized or printed.
    funding = requests.get(FRIENDBOT, params={"addr": key.public_key}, timeout=60)
    funding.raise_for_status()
    source = get_json(f"{HORIZON}/accounts/{key.public_key}")
    envelope = (TransactionBuilder(Account(key.public_key, int(source["sequence"])),
                                   network_passphrase=PASSPHRASE, base_fee=100)
                .add_hash_memo(bytes.fromhex(digest))
                .append_manage_data_op(DATA_NAME, bytes.fromhex(digest))
                .set_timeout(180).build())
    envelope.sign(key)
    txid = envelope.hash_hex()
    save(pending, {"transaction": txid, "account": key.public_key, "sha256": digest,
                   "network": "Stellar Testnet", "envelope_xdr": envelope.to_xdr()})
    # On timeout this pending record allows lookup by ID, without duplicate submission.
    submitted = requests.post(f"{HORIZON}/transactions", data={"tx": envelope.to_xdr()}, timeout=60)
    submitted.raise_for_status()
    result, tx = verify(manifest, txid, key.public_key)
    save(receipt, {"verification": result, "horizon_transaction": tx,
                   "fee_stroops_testnet": tx["fee_charged"], "real_money_spent": 0})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    add = sub.add_parser("anchor")
    add.add_argument("manifest", type=Path)
    add.add_argument("receipt", type=Path)
    check = sub.add_parser("verify")
    check.add_argument("manifest", type=Path)
    check.add_argument("--transaction", required=True)
    check.add_argument("--account", required=True)
    args = parser.parse_args()
    try:
        if args.command == "anchor":
            result = anchor(args.manifest, args.receipt)
        else:
            result, _ = verify(args.manifest, args.transaction, args.account)
        print(json.dumps(result, indent=2))
    except Exception as error:
        print(f"NOT VERIFIED: {type(error).__name__}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
