# RunPod ComfyUI Sulphur 2 GGUF Workflow Setup

One-command RunPod setup for the `Sulphur 2 (GGUF)` ComfyUI workflow.

This repo is built around a GGUF LTX 2.3 / Sulphur 2 workflow that uses `smthemex/ComfyUI_LTX2_SM` nodes instead of the standard checkpoint-only ComfyUI graph. The setup script installs ComfyUI, installs the required custom nodes, downloads the exact model filenames referenced by the workflow, and copies the workflow into ComfyUI's user workflow folder.

## What It Installs

- ComfyUI into `/workspace/ComfyUI`
- Python virtual environment at `/workspace/ComfyUI/venv`
- ComfyUI-Manager
- `smthemex/ComfyUI_LTX2_SM`
- `workflows/Sulphur 2 (GGUF).json`
- Neutral placeholder input image at `/workspace/ComfyUI/input/example.png`
- GGUF transformer: `sulphur_distil-Q6_K.gguf`
- GGUF text encoder: `gemma-3-12b-it-qat-Q4_0.gguf`
- Text connector: `connector-11.safetensors`
- Video VAE: `LTX23_video_vae_bf16.safetensors`
- Audio VAE: `LTX23_audio_vae_bf16.safetensors`
- Sulphur LoRA: `sulphur_lora_rank_768.safetensors`
- Spatial upscaler: `ltx-2.3-spatial-upscaler-x2-1.1.safetensors`
- Frame interpolation model: `film_net_fp16.safetensors`

## Recommended RunPod Template

Use a CUDA/PyTorch RunPod image with enough disk space for large model files.

Suggested minimums:

- GPU: 16 GB VRAM can be workable for GGUF/offload setups; 24 GB+ is more comfortable
- RAM: 48 GB+ is recommended by the `ComfyUI_LTX2_SM` workflow author
- Disk: 80 GB+ minimum, 120 GB+ safer
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

Open the RunPod HTTP service for port `8188`, then load `Sulphur 2 (GGUF).json` from the workflow menu. Replace `example.png` and the prompt inside ComfyUI before a real run.

## Workflow Models

The default setup downloads the full model set required by the included GGUF workflow:

```bash
./scripts/setup_runpod.sh
```

Skip all large GGUF/VAE/upscaler downloads if you already mounted the files:

```bash
DOWNLOAD_GGUF_MODELS=0 ./scripts/setup_runpod.sh
```

Skip the 10 GB Sulphur rank LoRA:

```bash
DOWNLOAD_RANK_LORA=0 ./scripts/setup_runpod.sh
```

Skip the frame interpolation model:

```bash
DOWNLOAD_FRAME_INTERPOLATION=0 ./scripts/setup_runpod.sh
```

Skip copying the workflow JSON:

```bash
DOWNLOAD_WORKFLOWS=0 ./scripts/setup_runpod.sh
```

## Optional Prompt Enhancer

Download the Sulphur prompt enhancer GGUF files as well:

```bash
DOWNLOAD_PROMPT_ENHANCER=1 ./scripts/setup_runpod.sh
```

The prompt enhancer files are placed in `/workspace/sulphur_prompt_enhancer`.

## Optional Lightricks Nodes

This workflow uses `ComfyUI_LTX2_SM`, so the official Lightricks custom node pack is not installed by default. Install it as an extra node pack if you want to experiment with other LTX workflows:

```bash
INSTALL_LTXVIDEO_NODES=1 ./scripts/setup_runpod.sh
```

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
/workspace/ComfyUI/models/gguf
/workspace/ComfyUI/models/checkpoints
/workspace/ComfyUI/models/vae
/workspace/ComfyUI/models/loras
/workspace/ComfyUI/models/latent_upscale_models
/workspace/ComfyUI/models/frame_interpolation
/workspace/ComfyUI/user/default/workflows
/workspace/start_comfyui.sh
```

Override the workspace:

```bash
WORKSPACE_DIR=/runpod-volume ./scripts/setup_runpod.sh
```

Use a different local workflow file:

```bash
WORKFLOW_FILE=/workspace/my-workflow.json ./scripts/setup_runpod.sh
```

## Notes

- Hugging Face downloads are large. Keep the RunPod pod alive until downloads finish.
- Some Hugging Face files may require accepting model license terms or being logged in with `HF_TOKEN`; if needed, run `export HF_TOKEN=hf_your_token_here` before the setup script.
- The included workflow is a neutral-prompt version of the local workflow this setup was based on. Swap prompts and input image inside ComfyUI after installation.
- Review upstream licenses before commercial use.

## Sources

- `ComfyUI_LTX2_SM`: <https://github.com/smthemex/ComfyUI_LTX2_SM>
- GGUF model files: <https://huggingface.co/smthem/LTX-2.3-test-gguf>
- VAE files: <https://huggingface.co/Kijai/LTX2.3_comfy>
- LTX 2.3 upscaler: <https://huggingface.co/Lightricks/LTX-2.3>
- Frame interpolation: <https://huggingface.co/Comfy-Org/frame_interpolation>
- Sulphur 2 Hugging Face repo: <https://huggingface.co/SulphurAI/Sulphur-2-base>
