import os, json, base64, time, urllib.request, urllib.error, traceback
from datetime import date
from flask import Flask, request, jsonify
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.backends import default_backend

app = Flask(__name__)

# In-memory rate limit: 10 requests per transactionId per day
_rate_limit = {}  # {"txnId_date": count}
_last_cleanup = ""

def _check_rate(tid):
    global _last_cleanup
    today = str(date.today())
    # Clean old entries once per day
    if _last_cleanup != today:
        for k in list(_rate_limit):
            if not k.endswith(f"_{today}"):
                del _rate_limit[k]
        _last_cleanup = today
    key = f"{tid}_{today}"
    count = _rate_limit.get(key, 0)
    if count >= 10:
        return False
    _rate_limit[key] = count + 1
    return True

APP_CONFIGS = {
    "com.xiedongze.BasketballRecord": {
        "issuer_id": "50853c64-5d54-42f0-85aa-a6e291d5066b",
        "key_id": "9S3HQX9676",
        "product_ids": ["com.doxie.basketball.pro.monthly", "com.doxie.basketball.pro.yearly"]
    }
}

APPLE_SANDBOX = "https://api.storekit-sandbox.itunes.apple.com"
APPLE_PRODUCTION = "https://api.storekit.itunes.apple.com"


def load_p8():
    raw = os.environ.get("APPSTORE_SERVER_P8", "")
    if raw:
        return raw.encode()
    b64 = os.environ.get("APPSTORE_SERVER_P8_BASE64", "")
    if b64:
        return base64.b64decode(b64)
    return b""

def make_jwt(issuer_id, key_id, bundle_id):
    p8 = load_p8()
    key = serialization.load_pem_private_key(p8, password=None, backend=default_backend())

    header = base64.urlsafe_b64encode(
        json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode()
    ).decode().rstrip("=")

    now = int(time.time())
    payload = base64.urlsafe_b64encode(
        json.dumps({
            "iss": issuer_id, "iat": now, "exp": now + 600,
            "aud": "appstoreconnect-v1", "bid": bundle_id
        }).encode()
    ).decode().rstrip("=")

    sig_der = key.sign(f"{header}.{payload}".encode(), ec.ECDSA(hashes.SHA256()))

    # Convert DER to raw (r||s) 64-byte for ES256
    r_len = sig_der[3]
    r = sig_der[4:4+r_len]
    if r[0] == 0:
        r = r[1:]
    s_len = sig_der[5+r_len]
    s = sig_der[6+r_len:6+r_len+s_len]
    if s[0] == 0:
        s = s[1:]

    sig_raw = r.rjust(32, b'\x00') + s.rjust(32, b'\x00')
    return f"{header}.{payload}.{base64.urlsafe_b64encode(sig_raw).decode().rstrip('=')}"


def verify_transaction(tid, config, bundle_id, client_token="", environment=""):
    token = make_jwt(config["issuer_id"], config["key_id"], bundle_id)
    urls = []
    if environment == "Sandbox":
        urls = [APPLE_SANDBOX]
    elif environment == "Production":
        urls = [APPLE_PRODUCTION]
    else:
        urls = [APPLE_PRODUCTION, APPLE_SANDBOX]
    for base_url in urls:
        url = f"{base_url}/inApps/v1/transactions/{tid}"
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                parts = json.loads(resp.read()).get("signedTransactionInfo", "").split(".")
                if len(parts) != 3:
                    continue
                info = json.loads(base64.urlsafe_b64decode(parts[1] + "=="))
                pid = info.get("productId", "")
                if pid not in config["product_ids"]:
                    return False, "wrong_product"
                if info.get("cancellationDate"):
                    return False, "cancelled"
                if info.get("bundleId") != bundle_id:
                    return False, "bundle_mismatch"
                if info.get("expiresDate", 0) <= int(time.time() * 1000):
                    return False, "expired"
                apple_token = info.get("appAccountToken", "")
                if apple_token and apple_token != client_token:
                    return False, "token_mismatch"
                return True, "active"
        except urllib.error.HTTPError as e:
            body = e.read().decode()
            if e.code == 404:
                continue
            return False, f"error_{e.code}: {body[:100]}"
        except Exception:
            continue
    return False, "not_found"


def call_ai(api_key, messages, system_prompt, temperature, max_tokens):
    full_messages = []
    if system_prompt:
        full_messages.append({"role": "system", "content": system_prompt})
    full_messages.extend(messages)

    body = json.dumps({
        "model": "deepseek-chat",
        "messages": full_messages,
        "temperature": temperature,
        "max_tokens": max_tokens
    }).encode()

    req = urllib.request.Request(
        "https://api.deepseek.com/chat/completions",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"error": f"deepseek_{e.code}: {e.read().decode()[:200]}"}
    except Exception as e:
        return {"error": str(e)}


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "cryptography": True})

@app.route("/v1/chat", methods=["POST"])
def chat():
    try:
        body = request.get_json(silent=True) or {}
        config = APP_CONFIGS.get("com.xiedongze.BasketballRecord")

        tid = body.get("transactionId", "")
        if not tid:
            return jsonify({"error": "transactionId required"}), 400

        if not _check_rate(tid):
            return jsonify({"error": "rate limit reached (10/day)"}), 429

        client_token = body.get("appAccountToken", "")
        env = body.get("environment", "")
        valid, status = verify_transaction(tid, config, "com.xiedongze.BasketballRecord", client_token, env)
        if not valid:
            return jsonify({"error": f"subscription {status}"}), 403

        api_key = os.environ.get("DEEPSEEK_API_KEY", "")
        if not api_key:
            return jsonify({"error": "server not configured"}), 500

        result = call_ai(
            api_key,
            body.get("messages", []),
            body.get("systemPrompt", ""),
            body.get("temperature", 0.6),
            body.get("maxTokens", 2500)
        )

        if "error" in result:
            return jsonify(result), 500
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e), "trace": traceback.format_exc()}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)
