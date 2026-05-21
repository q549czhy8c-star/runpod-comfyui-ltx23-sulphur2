# RunPod ComfyUI LTX 2.3 Sulphur 2 Setup

One-command RunPod setup for ComfyUI with LTX 2.3 / Sulphur 2 workflows.

Sulphur 2 is a community open-weights video model published at `SulphurAI/Sulphur-2-base` on Hugging Face. It is based on LTX 2.3 and supports text-to-video and image-to-video workflows in ComfyUI. The setup script installs ComfyUI, ComfyUI-Manager, LTXVideo nodes, downloads the Sulphur 2 checkpoint, optional distill LoRA, and the bundled workflow JSON files.

## What It Installs

- ComfyUI into `/workspace/ComfyUI`
- Python virtual environment at `/workspace/ComfyUI/venv`
- ComfyUI-Manager
- ComfyUI-LTXVideo custom nodes
- Sulphur 2 checkpoint, defaulting to `sulphur_dev_fp8mixed.safetensors`
- Sulphur 2 distill LoRA
- Four Sulphur 2 ComfyUI workflows:
  - `ltx23_t2v base.json`
  - `ltx23_t2v distilled.json`
  - `ltx23_i2v base.json`
  - `ltx23_i2v distilled.json`

## Recommended RunPod Template

Use a CUDA/PyTorch RunPod image with enough disk space for large video checkpoints.

Suggested minimums:

- GPU: 24 GB VRAM for fp8mixed, 32 GB+ preferred for bf16
- Disk: 80 GB+ for fp8mixed, 130 GB+ for bf16 and prompt enhancer
- Expose HTTP port: `8188`

## Quick Start

On a fresh RunPod terminal:

```bash
cd /workspace
git clone https://github.com/q549czhy8c-star/runpod-comfyui-ltx23-sulphur2.git
cd runpod-comfyui-ltx23-sulphur2
chmod +x scripts/setup_runpod.sh
./scripts/setup_runpod.sh
```

Start ComfyUI:

```bash
/workspace/start_comfyui.sh
```

Open the RunPod HTTP service for port `8188`.

## Model Variants

Default setup downloads the smaller fp8mixed Sulphur 2 checkpoint:

```bash
MODEL_VARIANT=fp8mixed ./scripts/setup_runpod.sh
```

For the full bf16 checkpoint:

```bash
MODEL_VARIANT=bf16 ./scripts/setup_runpod.sh
```

To install ComfyUI and nodes without downloading the base checkpoint:

```bash
MODEL_VARIANT=none ./scripts/setup_runpod.sh
```

## Optional Downloads

Skip the distill LoRA:

```bash
DOWNLOAD_LORA=0 ./scripts/setup_runpod.sh
```

Skip workflow JSON downloads:

```bash
DOWNLOAD_WORKFLOWS=0 ./scripts/setup_runpod.sh
```

Download the prompt enhancer GGUF files as well:

```bash
DOWNLOAD_PROMPT_ENHANCER=1 ./scripts/setup_runpod.sh
```

The prompt enhancer files are placed in `/workspace/sulphur_prompt_enhancer`.

## PyTorch / CUDA

The script creates a venv and installs PyTorch automatically if it cannot import `torch` inside the venv.

Default wheel index:

```bash
TORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
```

Override it if your RunPod image needs another CUDA wheel set:

```bash
TORCH_INDEX_URL=https://download.pytorch.org/whl/cu121 ./scripts/setup_runpod.sh
```

If your base image already provides the exact PyTorch build you want, skip torch install:

```bash
INSTALL_TORCH=0 ./scripts/setup_runpod.sh
```

## Paths

Default paths:

```text
/workspace/ComfyUI
/workspace/ComfyUI/models/checkpoints
/workspace/ComfyUI/models/loras
/workspace/ComfyUI/user/default/workflows
/workspace/start_comfyui.sh
```

Override the workspace:

```bash
WORKSPACE_DIR=/runpod-volume ./scripts/setup_runpod.sh
```

## Notes

- Hugging Face downloads are large. Keep the RunPod pod alive until downloads finish.
- Some Hugging Face files may require accepting model license terms or being logged in with `HF_TOKEN`; if needed, run `export HF_TOKEN=hf_your_token_here` before the setup script.
- The Sulphur model card recommends using either the full model or LoRA path, not both in the same workflow unless the workflow specifically expects it.
- Review the upstream licenses before commercial use.

## Sources

- ComfyUI LTX 2.3 workflow docs: <https://docs.comfy.org/tutorials/video/ltx/ltx-2-3>
- LTX 2.3 overview: <https://ltx.io/model/ltx-2-3>
- Sulphur 2 Hugging Face repo: <https://huggingface.co/SulphurAI/Sulphur-2-base>
