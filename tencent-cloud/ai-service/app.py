import os, json, base64, time, uuid, hmac, hashlib, urllib.request, urllib.error, urllib.parse, traceback, threading
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
        "model": "deepseek-v4-flash",
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


def _cos_put(key, data):
    if not COS_BUCKET or not COS_SECRET_ID or not COS_SECRET_KEY:
        return
    path = f"/{key}"
    host = f"{COS_BUCKET}.cos.{COS_REGION}.myqcloud.com"
    url = f"https://{host}{path}"

    sign_headers = {
        "Host": host,
        "x-cos-content-sha256": hashlib.sha256(data).hexdigest(),
    }
    auth = _v5_sign("PUT", path, sign_headers)

    req_headers = {
        "Authorization": auth,
        "Host": host,
        "x-cos-content-sha256": sign_headers["x-cos-content-sha256"],
        "Content-Type": "application/octet-stream",
    }

    req = urllib.request.Request(url, data=data, headers=req_headers, method="PUT")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            pass
    except Exception:
        pass


def _write_log(entry):
    if not COS_BUCKET:
        return
    now = datetime.now(timezone.utc)
    ts = now.strftime("%Y%m%dT%H%M%S")
    token = (entry.get("appAccountToken", "") or "unknown")[:8]
    log_key = "ai/basketball/{}/{:02d}/{}/request-{}-{}.json".format(now.year, now.month, token, ts, str(uuid.uuid4())[:8])
    threading.Thread(target=_cos_put, args=(log_key, json.dumps(entry, ensure_ascii=False).encode()), daemon=True).start()


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "cryptography": True})

@app.route("/v1/chat", methods=["POST"])
def chat():
    start_time = time.time()
    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "transactionId": "",
        "appAccountToken": "",
        "environment": "",
        "request": {},
        "response": {},
        "latencyMs": 0,
    }

    try:
        body = request.get_json(silent=True) or {}
        config = APP_CONFIGS.get("com.xiedongze.BasketballRecord")

        tid = body.get("transactionId", "")
        log_entry["transactionId"] = tid
        log_entry["appAccountToken"] = body.get("appAccountToken", "")
        log_entry["environment"] = body.get("environment", "")
        log_entry["request"] = {
            "messageCount": len(body.get("messages", [])),
            "systemPrompt": (body.get("systemPrompt", "") or "")[:200],
            "temperature": body.get("temperature", 0.6),
            "maxTokens": body.get("maxTokens", 2500),
        }

        if not tid:
            log_entry["response"] = {"status": "error", "error": "transactionId required"}
            _write_log(log_entry)
            return jsonify({"error": "transactionId required"}), 400

        if not _check_rate(tid):
            log_entry["response"] = {"status": "error", "error": "rate limit reached (10/day)"}
            _write_log(log_entry)
            return jsonify({"error": "rate limit reached (10/day)"}), 429

        client_token = body.get("appAccountToken", "")
        env = body.get("environment", "")
        valid, sub_status = verify_transaction(tid, config, "com.xiedongze.BasketballRecord", client_token, env)
        if not valid:
            log_entry["response"] = {"status": "error", "error": f"subscription {sub_status}"}
            _write_log(log_entry)
            return jsonify({"error": f"subscription {sub_status}"}), 403

        api_key = os.environ.get("DEEPSEEK_API_KEY", "")
        if not api_key:
            log_entry["response"] = {"status": "error", "error": "server not configured"}
            _write_log(log_entry)
            return jsonify({"error": "server not configured"}), 500

        result = call_ai(
            api_key,
            body.get("messages", []),
            body.get("systemPrompt", ""),
            body.get("temperature", 0.6),
            body.get("maxTokens", 2500)
        )

        log_entry["latencyMs"] = int((time.time() - start_time) * 1000)
        log_entry["deepSeekStatus"] = 200 if "error" not in result else 500

        if "error" in result:
            log_entry["response"] = {"status": "error", "error": result["error"]}
            _write_log(log_entry)
            return jsonify(result), 500

        usage = result.get("usage", {})
        content = ""
        choices = result.get("choices", [])
        if choices and isinstance(choices, list) and len(choices) > 0:
            content = (choices[0].get("message", {}).get("content", "") or "")[:200]

        log_entry["response"] = {
            "status": "success",
            "contentPreview": content,
            "promptTokens": usage.get("prompt_tokens", 0),
            "completionTokens": usage.get("completion_tokens", 0),
            "totalTokens": usage.get("total_tokens", 0),
        }
        _write_log(log_entry)
        return jsonify(result)

    except Exception as e:
        log_entry["latencyMs"] = int((time.time() - start_time) * 1000)
        log_entry["response"] = {"status": "error", "error": str(e)}
        _write_log(log_entry)
        return jsonify({"error": str(e), "trace": traceback.format_exc()}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)
