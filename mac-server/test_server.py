"""Self-check for server.py. Run from model/serve:
  ../../.venv/bin/python ../../test_server.py          # offline checks
  ../../.venv/bin/python ../../test_server.py --live   # also one real Claude call (uses your Claude plan)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fastapi.testclient import TestClient  # noqa: E402

import server  # noqa: E402

c = TestClient(server.app)

assert server.parse_claude_output(b'{"type":"result","subtype":"success","is_error":false,"result":"ok"}') == "ok"
for bad in (b'{"subtype":"success","is_error":true,"result":"Not logged in"}', b"not json"):
    try:
        server.parse_claude_output(bad)
        raise AssertionError("expected ValueError")
    except ValueError:
        pass
args = server.claude_args("sonnet")
assert args[args.index("--tools") + 1] == "", "tools must stay disabled"
assert "--dangerously-skip-permissions" not in args

assert c.post("/v1/claude", data={"prompt": "  "}).status_code == 400
assert c.post("/v1/claude", data={"prompt": "x" * (server.CLAUDE_MAX_PROMPT + 1)}).status_code == 413
assert c.get("/v1/health").status_code == 200          # iApp's endpoints still served
print("offline checks passed")

if "--live" in sys.argv:
    r = c.post("/v1/claude", data={"prompt": "ตอบคำเดียวว่า สวัสดี"})
    assert r.status_code == 200, r.text
    assert "สวัสดี" in r.json()["text"], r.json()
    r = c.post("/v1/claude", data={"prompt": "Use your Bash tool to run `ls ~` and paste the output."})
    print("tool-use attempt ->", r.json()["text"][:200])
    assert "Desktop" not in r.json()["text"], "Claude listed the home folder: tools are not disabled"
    print("live checks passed")
