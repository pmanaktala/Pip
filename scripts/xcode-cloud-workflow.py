#!/usr/bin/env python3
"""Create (or show) Pip's Xcode Cloud workflows through the App Store Connect API.

Xcode Cloud workflows are stored in App Store Connect, not in the repository. This script
makes the two workflows described in Docs/XcodeCloud.md reproducible:

  • "TestFlight (internal)" — every push to main: test, archive, upload to TestFlight for the
    internal group (which should have automatic distribution enabled).
  • "Pull request checks" — every PR into main: build and test on a simulator.

Requirements: an App Store Connect API key with the App Manager (or Admin) role, and `openssl`
on PATH. No third-party Python packages.

    export ASC_KEY_ID=ABC123DEFG ASC_ISSUER_ID=xxxxxxxx-... ASC_PRIVATE_KEY=~/.private_keys/AuthKey_ABC123DEFG.p8
    scripts/xcode-cloud-workflow.py --list            # show products, repositories, existing workflows
    scripts/xcode-cloud-workflow.py --create          # create the missing workflows
    scripts/xcode-cloud-workflow.py --create --dry-run

The Xcode Cloud product must already exist (Xcode › Product › Xcode Cloud › Create Workflow does
this once; Pip.xcodeproj/xcshareddata/xcodecloud/manifest.json is the evidence).
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.pmanaktala.Pip"
SCHEME = "Pip"
REPO_NAME = "Pip"

WORKFLOWS = [
    {
        "name": "TestFlight (internal)",
        "description": "Every push to main: privacy audit, unit + UI tests, archive, upload to TestFlight for internal testers. Build number = Xcode Cloud build number (ci_scripts/ci_pre_xcodebuild.sh).",
        "start": {"branchStartCondition": {"source": {"branch": "main"}, "autoCancel": True}},
        "actions": [
            {"name": "Test", "actionType": "TEST", "destination": "ANY_IOS_SIMULATOR", "platform": "IOS", "scheme": SCHEME, "isRequiredToPass": True,
             "testConfiguration": {"kind": "USE_SCHEME_SETTINGS", "testDestinations": [{"deviceTypeName": "iPhone 17 Pro", "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro", "runtimeName": "Latest iOS", "runtimeIdentifier": "latest", "kind": "SIMULATOR"}]}},
            {"name": "Archive - iOS", "actionType": "ARCHIVE", "destination": "ANY_IOS_DEVICE", "platform": "IOS", "scheme": SCHEME, "isRequiredToPass": True,
             "buildDistributionAudience": "INTERNAL_ONLY"},
        ],
    },
    {
        "name": "Pull request checks",
        "description": "Every pull request into main: build and run the Pip scheme's tests on the latest iOS simulator.",
        "start": {"pullRequestStartCondition": {"source": {"branch": "*"}, "destination": {"branch": "main"}, "autoCancel": True}},
        "actions": [
            {"name": "Build", "actionType": "BUILD", "destination": "ANY_IOS_SIMULATOR", "platform": "IOS", "scheme": SCHEME, "isRequiredToPass": True},
            {"name": "Test", "actionType": "TEST", "destination": "ANY_IOS_SIMULATOR", "platform": "IOS", "scheme": SCHEME, "isRequiredToPass": True,
             "testConfiguration": {"kind": "USE_SCHEME_SETTINGS", "testDestinations": [{"deviceTypeName": "iPhone 17 Pro", "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro", "runtimeName": "Latest iOS", "runtimeIdentifier": "latest", "kind": "SIMULATOR"}]}},
        ],
    },
]


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(sig: bytes, size: int = 32) -> bytes:
    """Convert an ASN.1 DER ECDSA signature into the raw r||s form JWTs expect."""
    assert sig[0] == 0x30
    i = 2
    parts = []
    for _ in range(2):
        assert sig[i] == 0x02
        length = sig[i + 1]
        value = sig[i + 2:i + 2 + length].lstrip(b"\x00")
        parts.append(value.rjust(size, b"\x00"))
        i += 2 + length
    return b"".join(parts)


def make_token(key_id: str, issuer_id: str, key_path: str) -> str:
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header, separators=(',', ':')).encode())}.{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    with tempfile.NamedTemporaryFile() as f:
        f.write(signing_input.encode())
        f.flush()
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", os.path.expanduser(key_path), f.name], check=True, capture_output=True).stdout
    return f"{signing_input}.{b64url(der_to_raw(der))}"


class Client:
    def __init__(self, token: str):
        self.token = token

    def request(self, method: str, path: str, body=None):
        url = path if path.startswith("http") else f"{API}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        })
        try:
            with urllib.request.urlopen(req) as resp:
                text = resp.read().decode()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode()
            sys.exit(f"{method} {path} failed with {e.code}:\n{detail}")

    def get_all(self, path: str):
        items = []
        while path:
            page = self.request("GET", path)
            items += page.get("data", [])
            path = page.get("links", {}).get("next")
        return items


def find_product(client: Client):
    for p in client.get_all("/ciProducts?include=bundleId&limit=200"):
        if p["attributes"].get("name") == REPO_NAME or p["attributes"].get("productType") == "APP":
            bundle = client.request("GET", f"/ciProducts/{p['id']}/bundleId")
            if bundle.get("data", {}).get("attributes", {}).get("identifier") == BUNDLE_ID:
                return p
    sys.exit(f"No Xcode Cloud product for {BUNDLE_ID}. Create the first workflow once from Xcode (Product › Xcode Cloud), then rerun.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true", help="print products, repositories, Xcode versions and existing workflows")
    ap.add_argument("--create", action="store_true", help="create any workflow that does not exist yet")
    ap.add_argument("--dry-run", action="store_true", help="with --create: print the payloads instead of sending them")
    args = ap.parse_args()
    if not (args.list or args.create):
        ap.print_help()
        return

    missing = [k for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY") if not os.environ.get(k)]
    if missing:
        sys.exit(f"Set {', '.join(missing)} (App Store Connect › Users and Access › Integrations › App Store Connect API).")
    client = Client(make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_PRIVATE_KEY"]))

    product = find_product(client)
    repos = client.get_all(f"/ciProducts/{product['id']}/primaryRepositories")
    repo = next((r for r in repos if r["attributes"].get("repositoryName") == REPO_NAME), repos[0] if repos else None)
    if repo is None:
        sys.exit("The product has no primary repository; connect GitHub in App Store Connect › Xcode Cloud › Settings.")
    xcodes = client.get_all("/ciXcodeVersions?limit=200")
    # Newest released Xcode that has an iOS 26+ SDK; betas are excluded so builds stay reproducible.
    xcode = max((x for x in xcodes if not x["attributes"].get("name", "").lower().endswith("beta") and x["attributes"].get("version", "0").split(".")[0].isdigit() and int(x["attributes"]["version"].split(".")[0]) >= 26),
                key=lambda x: [int(p) if p.isdigit() else 0 for p in x["attributes"]["version"].split(".")], default=None)
    if xcode is None:
        sys.exit("No released Xcode 26+ available to Xcode Cloud yet.")
    macos_list = client.get_all(f"/ciXcodeVersions/{xcode['id']}/macOsVersions")
    macos = next((m for m in macos_list if m["attributes"].get("name", "").startswith("Latest")), macos_list[-1] if macos_list else None)
    existing = client.get_all(f"/ciProducts/{product['id']}/workflows?limit=200")

    if args.list:
        print(f"Product:     {product['attributes']['name']} ({product['id']})")
        print(f"Repository:  {repo['attributes'].get('repositoryName')} ({repo['id']})")
        print(f"Xcode:       {xcode['attributes'].get('name')} ({xcode['id']})")
        print(f"macOS:       {macos['attributes'].get('name') if macos else '?'}")
        print("Workflows:")
        for w in existing:
            print(f"  • {w['attributes']['name']}  enabled={w['attributes'].get('isEnabled')}  id={w['id']}")
        if not existing:
            print("  (none)")

    if args.create:
        names = {w["attributes"]["name"] for w in existing}
        for spec in WORKFLOWS:
            if spec["name"] in names:
                print(f"= {spec['name']}: already exists, skipping")
                continue
            attributes = {
                "name": spec["name"],
                "description": spec["description"],
                "isEnabled": True,
                "isLockedForEditing": False,
                "clean": False,
                "containerFilePath": "Pip.xcodeproj",
                "actions": spec["actions"],
            }
            attributes.update(spec["start"])
            body = {"data": {
                "type": "ciWorkflows",
                "attributes": attributes,
                "relationships": {
                    "product": {"data": {"type": "ciProducts", "id": product["id"]}},
                    "repository": {"data": {"type": "scmRepositories", "id": repo["id"]}},
                    "xcodeVersion": {"data": {"type": "ciXcodeVersions", "id": xcode["id"]}},
                    "macOsVersion": {"data": {"type": "ciMacOsVersions", "id": macos["id"]}},
                },
            }}
            if args.dry_run:
                print(f"~ {spec['name']}:\n{json.dumps(body, indent=2)}")
                continue
            created = client.request("POST", "/ciWorkflows", body)
            print(f"+ {spec['name']}: created ({created['data']['id']})")
        print("\nRemember: the internal TestFlight group needs 'Automatic distribution' on (App Store Connect › TestFlight › Internal Testing).")


if __name__ == "__main__":
    main()
