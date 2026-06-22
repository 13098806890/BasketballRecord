import json, os, base64

def main_handler(event, context):
    try:
        raw = event.get("body", "{}")
        if event.get("isBase64Encoded", False):
            raw = base64.b64decode(raw).decode("utf-8")
        if isinstance(raw, str):
            body = json.loads(raw)
        else:
            body = raw

        action = body.get("action", "")

        if action == "getDeepSeekKey":
            key = os.environ.get("DEEPSEEK_API_KEY", "")
            if not key:
                return res(500, {"error": "DEEPSEEK_API_KEY not configured"})
            return res(200, {"key": key})

        return res(400, {"error": "unknown action"})

    except Exception as e:
        return res(500, {"error": str(e)})

def res(code, data):
    return {
        "isBase64Encoded": False,
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(data)
    }
