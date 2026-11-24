#!/bin/bash
# Reproduces the Mac transcription server: Python venv, NeMo, FastAPI, and the OpenThai 2.0 ASR weights (~2.6 GB).
# Requires Homebrew uv and ffmpeg: brew install uv ffmpeg
set -euo pipefail
cd "$(dirname "$0")"

uv venv .venv --python 3.12
# shellcheck source=/dev/null
source .venv/bin/activate
uv pip install torch==2.13.0 Cython packaging
uv pip install --index-strategy unsafe-best-match \
    "nemo-toolkit[asr] @ git+https://github.com/NVIDIA-NeMo/Speech.git@cf724ac337d1ebc7d0dda1e23fb80916f52927a5" \
    fastapi uvicorn python-multipart websockets

uvx --from huggingface_hub hf download iapp/OpenThai2.0-ASR-Streaming --local-dir model --exclude "*.nemo"
uvx --from huggingface_hub hf download iapp/OpenThai2.0-ASR-Streaming openthai2.0-asr-streaming_raw.nemo --local-dir model

echo "Done. Start the menu-bar app \"MeetingRecorder Server\", or run:"
echo "  cd model/serve && ../../.venv/bin/python -m uvicorn server:app --app-dir ../.. --host 127.0.0.1 --port 18081"
