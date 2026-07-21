import os
import json
import uuid
import time
import hmac
import hashlib
import base64
import urllib.request
import urllib.error
import urllib.parse
import xml.etree.ElementTree as ET
import email.utils as email_utils
from datetime import date, datetime, timezone
from flask import Flask, request, jsonify
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.backends import default_backend

app = Flask(__name__)

COS_BUCKET = os.environ.get("COS_BUCKET", "")
COS_REGION = os.environ.get("COS_REGION", "ap-shanghai")
COS_SECRET_ID = os.environ.get("COS_SECRET_ID", "")
COS_SECRET_KEY = os.environ.get("COS_SECRET_KEY", "")
TEAM_ID = os.environ.get("TEAM_ID", "")

DEVICECHECK_KEY_ID = os.environ.get("DEVICECHECK_KEY_ID", "")

_apple_devicecheck_p8 = None
_p8_load_error = None

_rate_limit = {}
_last_cleanup = ""


def _v5_sign(method, path, headers, params=""):
    now = int(time.time())
    start = now - 60
    end = now + 3600
    key_time = f"{start};{end}"

    sign_key = hmac.new(
        COS_SECRET_KEY.encode(), key_time.encode(), hashlib.sha1
    ).hexdigest()

    sorted_headers = sorted(headers.items(), key=lambda x: x[0].lower())
    header_parts = []
    header_names = []
    for k, v in sorted_headers:
        ek = urllib.parse.quote(k.lower(), safe="")
        ev = urllib.parse.quote(str(v).strip(), safe="")
        header_parts.append(f"{ek}={ev}")
        header_names.append(ek)

    http_headers = "&".join(header_parts)
    header_list = ";".join(header_names)

    http_string = f"{method.lower()}\n{path}\n{params}\n{http_headers}\n"
    sha1_http = hashlib.sha1(http_string.encode()).hexdigest()
    string_to_sign = f"sha1\n{key_time}\n{sha1_http}\n"
    signature = hmac.new(
        sign_key.encode(), string_to_sign.encode(), hashlib.sha1
    ).hexdigest()

    return (
        f"q-sign-algorithm=sha1"
        f"&q-ak={COS_SECRET_ID}"
        f"&q-sign-time={key_time}"
        f"&q-key-time={key_time}"
        f"&q-header-list={header_list}"
        f"&q-url-param-list="
        f"&q-signature={signature}"
    )


def _cos_request(method, key, data=None):
    path = f"/{key}"
    host = f"{COS_BUCKET}.cos.{COS_REGION}.myqcloud.com"
    url = f"https://{host}{path}"

    sign_headers = {
        "Host": host,
    }
    if data is not None:
        body_hash = hashlib.sha256(data).hexdigest()
        sign_headers["x-cos-content-sha256"] = body_hash

    auth = _v5_sign(method, path, sign_headers)

    req_headers = {
        "Authorization": auth,
        "Host": host,
    }
    if data is not None:
        req_headers["x-cos-content-sha256"] = sign_headers["x-cos-content-sha256"]
        req_headers["Content-Type"] = "application/octet-stream"

    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, resp.read(), dict(resp.info())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:500]
        if e.code == 404:
            return e.code, None, {}
        raise Exception(f"{method} {path}: HTTP {e.code}: {body}")


def _load_devicecheck_p8():
    global _apple_devicecheck_p8, _p8_load_error
    if _apple_devicecheck_p8 is not None:
        return _apple_devicecheck_p8
    raw = os.environ.get("APPLE_DEVICECHECK_P8", "")
    if not raw or "BEGIN PRIVATE KEY" not in raw:
        _p8_load_error = "empty or missing header"
        return None
    try:
        body = raw.strip()
        if "\n" not in body:
            body = body.replace("-----BEGIN PRIVATE KEY-----", "-----BEGIN PRIVATE KEY-----\n")
            body = body.replace("-----END PRIVATE KEY-----", "\n-----END PRIVATE KEY-----")
            parts = body.split("-----BEGIN PRIVATE KEY-----\n")
            if len(parts) == 2:
                content = parts[1].replace("-----END PRIVATE KEY-----", "").strip()
                body = f"-----BEGIN PRIVATE KEY-----\n{content}\n-----END PRIVATE KEY-----"
        _apple_devicecheck_p8 = serialization.load_pem_private_key(
            body.encode(), password=None, backend=default_backend()
        )
        _p8_load_error = None
        return _apple_devicecheck_p8
    except Exception as e:
        _p8_load_error = str(e)
        return None


def _make_devicecheck_jwt():
    key = _load_devicecheck_p8()
    if key is None:
        return None

    now = int(time.time())
    header = base64.urlsafe_b64encode(
        json.dumps({"alg": "ES256", "kid": DEVICECHECK_KEY_ID, "typ": "JWT"}).encode()
    ).decode().rstrip("=")

    payload = base64.urlsafe_b64encode(
        json.dumps({
            "iss": TEAM_ID, "iat": now, "exp": now + 600
        }).encode()
    ).decode().rstrip("=")

    sig_der = key.sign(f"{header}.{payload}".encode(), ec.ECDSA(hashes.SHA256()))
    r_len = sig_der[3]
    r = sig_der[4:4 + r_len]
    if r[0] == 0:
        r = r[1:]
    s_len = sig_der[5 + r_len]
    s = sig_der[6 + r_len:6 + r_len + s_len]
    if s[0] == 0:
        s = s[1:]
    sig_raw = r.rjust(32, b'\x00') + s.rjust(32, b'\x00')
    sig_b64 = base64.urlsafe_b64encode(sig_raw).decode().rstrip("=")

    return f"{header}.{payload}.{sig_b64}"


def _verify_device_token(device_token):
    jwt = _make_devicecheck_jwt()
    if jwt is None:
        return None

    body = json.dumps({
        "device_token": device_token,
        "transaction_id": str(uuid.uuid4()),
        "timestamp": int(time.time() * 1000),
    }).encode()

    req = urllib.request.Request(
        "https://api.development.devicecheck.apple.com/v1/validate_device_token",
        data=body,
        headers={
            "Authorization": f"Bearer {jwt}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15):
            return True
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        return f"apple_error: HTTP {e.code} {body}"
    except Exception as e:
        return f"exception: {str(e)}"


def _check_rate(ip):
    global _last_cleanup
    today = str(date.today())
    if _last_cleanup != today:
        for k in list(_rate_limit):
            if not k.endswith(f"_{today}"):
                del _rate_limit[k]
        _last_cleanup = today
    key = f"{ip}_{today}"
    count = _rate_limit.get(key, 0)
    if count >= 50:
        return False
    _rate_limit[key] = count + 1
    return True


def _get_client_ip():
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.remote_addr or "unknown"


TTL = 72 * 3600

def _check_exists(key):
    try:
        status, _, _ = _cos_request("HEAD", key)
        return status == 200
    except Exception:
        return False


def _get_remaining_seconds(key):
    try:
        status, _, headers = _cos_request("HEAD", key)
        if status != 200:
            return 0
        last_modified = headers.get("Last-Modified", "")
        if not last_modified:
            return 0
        parsed = email_utils.parsedate_tz(last_modified)
        if parsed is None:
            return 0
        created = int(email_utils.mktime_tz(parsed))
        elapsed = time.time() - created
        remaining = max(0, int(TTL - elapsed))
        return remaining
    except Exception:
        return 0


def _uid_timestamp(uid):
    manifest = _load_manifest()
    for entry in manifest:
        if entry.get("uuid") == uid:
            return entry.get("created_at")
    return None


def _month_path(base, uid, ts=None):
    if ts is None:
        ts = _uid_timestamp(uid)
    if ts is None:
        ts = time.time()
    dt = datetime.fromtimestamp(ts, tz=timezone.utc)
    return f"{base}/{dt.year}/{dt.month:02d}/{uid}"


def _generate_key(uid, ts=None):
    return _month_path("shares", uid, ts) + ".json"


def _photo_key(uid, pid, ts=None):
    return _month_path("shares", uid, ts) + f"/photos/{pid}.jpg"


@app.route("/v2/debug", methods=["GET"])
def debug():
    p8_raw = os.environ.get("APPLE_DEVICECHECK_P8", "")
    jwt_info = {}
    apple_test = None
    try:
        jwt = _make_devicecheck_jwt()
        if jwt:
            body = json.dumps({
                "device_token": "test_disabled_token",
                "transaction_id": str(uuid.uuid4()),
                "timestamp": int(time.time() * 1000),
            }).encode()
            req = urllib.request.Request(
                "https://api.development.devicecheck.apple.com/v1/validate_device_token",
                data=body, headers={"Authorization": f"Bearer {jwt}", "Content-Type": "application/json"},
            )
            try:
                with urllib.request.urlopen(req, timeout=10):
                    apple_test = "200"
            except urllib.error.HTTPError as e:
                apple_test = f"HTTP {e.code}: {e.read().decode()[:100]}"
            except Exception as e:
                apple_test = f"network: {str(e)}"
        else:
            apple_test = "no_jwt"
    except Exception as e:
        apple_test = f"error: {str(e)}"
    return jsonify({
        "status": "ok",
        "jwt": jwt_info,
        "apple_test": apple_test,
        "has_bucket": bool(COS_BUCKET),
        "has_secret_id": bool(COS_SECRET_ID),
        "has_secret_key": bool(COS_SECRET_KEY),
        "has_team_id": bool(TEAM_ID),
        "has_devicecheck_key_id": bool(DEVICECHECK_KEY_ID),
        "p8_length": len(p8_raw),
        "p8_has_header": "BEGIN PRIVATE KEY" in p8_raw,
        "p8_has_footer": "END PRIVATE KEY" in p8_raw,
        "p8_has_newline": "\n" in p8_raw,
        "p8_preview": (p8_raw[:80] + "...") if p8_raw else "(empty)",
        "p8_valid": _load_devicecheck_p8() is not None,
        "p8_load_error": _p8_load_error,
    })


MANIFEST_KEY = "shares/_manifest.json"


def _load_manifest():
    try:
        _, data, _ = _cos_request("GET", MANIFEST_KEY)
        if data:
            return json.loads(data.decode())
    except Exception:
        pass
    return []


def _save_manifest(entries):
    _cos_request("PUT", MANIFEST_KEY, data=json.dumps(entries).encode())


@app.route("/v2/upload", methods=["PUT"])
def upload():
    if not COS_BUCKET:
        return jsonify({"error": "server not configured"}), 500

    ip = _get_client_ip()
    if not _check_rate(ip):
        return jsonify({"error": "rate limit exceeded"}), 429

    uid = str(uuid.uuid4())
    key = _generate_key(uid)
    data = request.get_data()

    if not data:
        return jsonify({"error": "empty body"}), 400

    try:
        _cos_request("PUT", key, data=data)
        manifest = _load_manifest()
        manifest.append({"uuid": uid, "created_at": time.time()})
        _save_manifest(manifest)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"uuid": uid}), 201


@app.route("/v2/download", methods=["POST"])
def download():
    if not COS_BUCKET:
        return jsonify({"error": "server not configured"}), 500

    body = request.get_json(silent=True) or {}
    uid = (body.get("uuid") or "").strip()
    if not uid:
        return jsonify({"error": "uuid required"}), 400

    try:
        uid_obj = uuid.UUID(uid)
        uid = str(uid_obj)
    except ValueError:
        return jsonify({"error": "invalid uuid"}), 400

    key = _generate_key(uid)
    if not _check_exists(key):
        return jsonify({"error": "not found"}), 404

    try:
        _, data, _ = _cos_request("GET", key)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return data, 200, {"Content-Type": "application/octet-stream"}


@app.route("/v2/check/<uid>", methods=["GET"])
def check(uid):
    if not COS_BUCKET:
        return jsonify({"error": "server not configured"}), 500

    try:
        uid_obj = uuid.UUID(uid)
        uid = str(uid_obj)
    except ValueError:
        return jsonify({"exists": False}), 404

    key = _generate_key(uid)
    remaining = _get_remaining_seconds(key)
    exists = remaining > 0
    if not exists:
        try:
            _cos_request("DELETE", key)
        except Exception:
            pass
    return jsonify({
        "exists": exists,
        "remainingSeconds": remaining if exists else 0,
    })


@app.route("/v2/upload/photo/<uid>/<pid>", methods=["PUT"])
def upload_photo(uid, pid):
    if not COS_BUCKET:
        return jsonify({"error": "server not configured"}), 500

    try:
        uuid.UUID(uid)
        uuid.UUID(pid)
    except ValueError:
        return jsonify({"error": "invalid uuid"}), 400

    ip = _get_client_ip()
    if not _check_rate(ip):
        return jsonify({"error": "rate limit exceeded"}), 429

    data = request.get_data()
    if not data:
        return jsonify({"error": "empty body"}), 400

    key = _photo_key(uid, pid)
    try:
        _cos_request("PUT", key, data=data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"ok": True}), 201


@app.route("/v2/download/photo/<uid>/<pid>", methods=["GET"])
def download_photo(uid, pid):
    if not COS_BUCKET:
        return jsonify({"error": "server not configured"}), 500

    try:
        uuid.UUID(uid)
        uuid.UUID(pid)
    except ValueError:
        return jsonify({"error": "invalid uuid"}), 400

    key = _photo_key(uid, pid)
    if not _check_exists(key):
        return jsonify({"error": "not found"}), 404

    try:
        _, data, _ = _cos_request("GET", key)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return data, 200, {"Content-Type": "application/octet-stream"}


def _do_cleanup():
    if not COS_BUCKET:
        return {"deleted": 0, "errors": 0}

    TTL = 72 * 3600
    now = time.time()
    deleted = 0
    errors = 0

    manifest = _load_manifest()
    remaining = []

    for entry in manifest:
        uid = entry.get("uuid", "")
        created = entry.get("created_at", 0)
        if now - created > TTL:
            try:
                key = _generate_key(uid, created)
                _cos_request("DELETE", key)
                deleted += 1
            except Exception:
                errors += 1
        else:
            remaining.append(entry)

    if remaining != manifest:
        _save_manifest(remaining)

    return {"deleted": deleted, "errors": errors}

    return {"deleted": deleted, "errors": errors}


@app.route("/v2/cleanup", methods=["POST"])
def cleanup():
    return jsonify(_do_cleanup())


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


@app.route("/v2/debug/manifest", methods=["GET"])
def debug_manifest():
    return jsonify({"entries": _load_manifest(), "count": len(_load_manifest())})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)
