"""MeetingMe Mac server: iApp's OpenThai ASR service (model/serve/app.py, downloaded, unchanged) plus our own endpoints.

  cd model/serve && ../../.venv/bin/python -m uvicorn server:app --app-dir ../.. --host 127.0.0.1 --port 18081

Added endpoint:
  POST /v1/claude   form `prompt` -> {"text", "processing_s"}. Runs the Claude Code CLI (`claude -p`) with the user's own
                    Claude login on this Mac (no API key; uses their plan's usage). All tools off.
                    CHINDA_CLAUDE_MODEL picks the model (default sonnet).
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
import tempfile
import time

from fastapi import Form, HTTPException

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "model", "serve"))
from app import app  # noqa: E402  iApp's FastAPI app; run from model/serve so its relative model path resolves

log = logging.getLogger("meetingme")

CLAUDE_MAX_PROMPT = 400_000      # characters; a 3 h Thai transcript is well under this
CLAUDE_TIMEOUT_S = 600
CLAUDE_SYSTEM = ("You help with the user's own meeting transcripts. You have no tools. "
                 "Answer with the requested text only, no preamble.")


def claude_args(model: str) -> list[str]:
    # The prompt arrives over the network: no tools, no MCP servers, no user settings or hooks, nothing saved.
    # Not --bare: it requires an API key instead of the user's Claude login.
    return ["claude", "-p", "--tools", "", "--strict-mcp-config", "--setting-sources", "",
            "--no-session-persistence", "--output-format", "json", "--model", model, "--system-prompt", CLAUDE_SYSTEM]


def parse_claude_output(out: bytes) -> str:
    """`claude -p --output-format json` stdout -> the answer text; ValueError carrying Claude's message on failure."""
    try:
        d = json.loads(out)
    except ValueError as e:
        raise ValueError(f"unexpected output from claude: {out[:300]!r}") from e
    if d.get("is_error") or d.get("subtype") != "success":
        raise ValueError(str(d.get("result") or d.get("subtype") or "claude failed"))
    return str(d.get("result", ""))


@app.post("/v1/claude")
async def claude(prompt: str = Form(...)):
    if not prompt.strip():
        raise HTTPException(status_code=400, detail="empty prompt")
    if len(prompt) > CLAUDE_MAX_PROMPT:
        raise HTTPException(status_code=413, detail=f"prompt longer than {CLAUDE_MAX_PROMPT} characters")
    t0 = time.time()
    with tempfile.TemporaryDirectory() as cwd:          # empty folder: Claude Code sees no files from this Mac
        try:
            proc = await asyncio.create_subprocess_exec(
                *claude_args(os.environ.get("CHINDA_CLAUDE_MODEL", "sonnet")), cwd=cwd,
                stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        except FileNotFoundError as e:
            raise HTTPException(status_code=503, detail="Claude Code is not installed on this Mac") from e
        try:
            out, err = await asyncio.wait_for(proc.communicate(prompt.encode()), CLAUDE_TIMEOUT_S)
        except asyncio.TimeoutError as e:
            proc.kill()
            await proc.wait()
            raise HTTPException(status_code=504, detail="Claude did not answer in time") from e
    try:
        text = parse_claude_output(out)
    except ValueError as e:
        log.warning("claude failed (exit %s): %s %s", proc.returncode, e, err[-500:])
        raise HTTPException(status_code=502, detail=str(e)) from e
    return {"text": text, "processing_s": round(time.time() - t0, 3)}
