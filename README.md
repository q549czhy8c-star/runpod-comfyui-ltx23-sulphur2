# RunPod Sulphur 2 Setup for ComfyUI Template

This guide is for starting Sulphur 2 on RunPod using a ComfyUI template.

You do not need to understand the code. The setup script will install the missing custom nodes, download the model files, copy the workflow into ComfyUI, and create a small example image so the workflow can open cleanly.

## Before You Start

Use a RunPod ComfyUI template, such as:

<https://console.runpod.io/hub/template/comfyui?id=cw3nka7d08>

Recommended pod settings:

- GPU: 24 GB VRAM or more is recommended
- Pod volume: 120 GB or more is safer
- HTTP port: `8188`

The download is large, so the setup may take a while. Keep the pod running until it finishes.

## Step 1: Start The Pod

1. Open the RunPod ComfyUI template.
2. Choose your GPU.
3. Set enough disk/pod volume space.
4. Deploy the pod.
5. Wait until the pod says it is running.

## Step 2: Open The Pod Terminal

In RunPod, open your pod and click **Connect**.

Open the **Web Terminal** or **Start Web Terminal** option.

## Step 3: Paste This Setup Command

Copy and paste this whole block into the RunPod terminal:

```bash
cd /workspace
git clone https://github.com/q549czhy8c-star/runpod-comfyui-ltx23-sulphur2.git
cd runpod-comfyui-ltx23-sulphur2
chmod +x scripts/setup_runpod.sh
./scripts/setup_runpod.sh
```

Wait until you see `Done`.

If the terminal shows a Hugging Face permission or license error, you may need a Hugging Face token. Run this first, then run the setup command again:

```bash
export HF_TOKEN=hf_your_token_here
```

## Step 4: Restart ComfyUI

The ComfyUI template may already be running before setup. After the setup finishes, restart ComfyUI so it can load the new Sulphur 2 custom nodes.

The easiest way:

1. Stop the current ComfyUI process in the terminal if it is running.
2. Start ComfyUI again with:

```bash
/workspace/start_comfyui.sh
```

If your template has a RunPod button to restart the service, you can use that instead.

## Step 5: Open ComfyUI

In RunPod, open the HTTP service for port `8188`.

In ComfyUI:

1. Open the workflow menu.
2. Load `Sulphur 2 (GGUF).json`.
3. The workflow starts with `example.png`.
4. Replace `example.png` with your own image.
5. Replace the prompt with what you want to generate.
6. Click **Queue Prompt**.

## What The Script Installs

- Sulphur 2 workflow: `Sulphur 2 (GGUF).json`
- Custom node: `ComfyUI_LTX2_SM`
- Sulphur 2 GGUF model: `sulphur_distil-Q6_K.gguf`
- GGUF text encoder: `gemma-3-12b-it-qat-Q4_0.gguf`
- Text connector: `connector-11.safetensors`
- Video VAE: `LTX23_video_vae_bf16.safetensors`
- Audio VAE: `LTX23_audio_vae_bf16.safetensors`
- Sulphur LoRA: `sulphur_lora_rank_768.safetensors`
- Spatial upscaler: `ltx-2.3-spatial-upscaler-x2-1.1.safetensors`
- Frame interpolation model: `film_net_fp16.safetensors`
- Example input image: `/workspace/ComfyUI/input/example.png`

## Useful Paths

You normally do not need these, but they help if you want to check files:

```text
/workspace/ComfyUI
/workspace/ComfyUI/user/default/workflows/Sulphur 2 (GGUF).json
/workspace/ComfyUI/input/example.png
/workspace/start_comfyui.sh
```

## If Something Goes Wrong

- If ComfyUI says nodes are missing, restart ComfyUI after setup.
- If a model is missing, run `./scripts/setup_runpod.sh` again.
- If Hugging Face blocks a download, set `HF_TOKEN` and run the script again.
- If the pod runs out of disk space, increase the pod volume and run the script again.

## Advanced Options

## Workflow Models

The default setup downloads the full model set required by the Sulphur 2 GGUF workflow:

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

## Wan2.2 PainterI2V Workflow

This repo also includes a separate setup script for `Wan2.2_I2V_PainterI2V_Workflow_Kenpechi_v2.4.json`.

Run it on a fresh RunPod pod:

```bash
cd /workspace
git clone https://github.com/q549czhy8c-star/runpod-comfyui-ltx23-sulphur2.git
cd runpod-comfyui-ltx23-sulphur2
chmod +x scripts/setup_wan22_painteri2v.sh
./scripts/setup_wan22_painteri2v.sh
```

Start ComfyUI:

```bash
/workspace/start_comfyui.sh
```

The Wan workflow is copied to:

```text
/workspace/ComfyUI/user/default/workflows/Wan2.2_I2V_PainterI2V_Workflow_Kenpechi_v2.4.json
```

### Wan2.2 Defaults

The script installs the custom nodes used by the workflow:

- `rgthree-comfy`
- `ComfyUI-KJNodes`
- `ComfyUI-Impact-Pack`
- `ComfyUI-Custom-Scripts`
- `ComfyUI-GGUF`
- `ComfyUI-VideoHelperSuite`
- `ComfyUI-PainterI2Vadvanced`
- `ComfyUI-Frame-Interpolation`

By default it downloads the GGUF route used by the workflow:

- `Wan2.2-I2V-A14B-HighNoise-Q8_0.gguf`
- `Wan2.2-I2V-A14B-LowNoise-Q8_0.gguf`
- `umt5_xxl_fp8_e4m3fn_scaled.safetensors`
- `wan_2.1_vae.safetensors`
- Lightx2v high/low LoRAs
- FFGO high/low LoRAs
- `RealESRGAN_x2plus.pth`
- `rife49.pth`

Optional switches:

```bash
DOWNLOAD_GGUF_MODELS=0 ./scripts/setup_wan22_painteri2v.sh
DOWNLOAD_SAFETENSORS_MODELS=1 ./scripts/setup_wan22_painteri2v.sh
DOWNLOAD_LIGHTX2V_LORAS=0 ./scripts/setup_wan22_painteri2v.sh
DOWNLOAD_FFGO_LORAS=0 ./scripts/setup_wan22_painteri2v.sh
DOWNLOAD_UPSCALE_MODEL=0 ./scripts/setup_wan22_painteri2v.sh
DOWNLOAD_RIFE_MODEL=0 ./scripts/setup_wan22_painteri2v.sh
```

The included Wan workflow is a neutral-prompt version of the local workflow it was based on. Replace `example.png`, prompts, and optional Power LoRA entries inside ComfyUI after installation.

Wan2.2 sources:

- Wan GGUF high/low noise models: <https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF>
- Wan ComfyUI repackaged models: <https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged>
- Wan text encoder and VAE: <https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged>
- Lightx2v distill LoRAs: <https://huggingface.co/lightx2v/Wan2.2-Distill-Loras>
- Kijai WanVideo assets: <https://huggingface.co/Kijai/WanVideo_comfy>
- PainterI2V Advanced: <https://github.com/princepainter/ComfyUI-PainterI2Vadvanced>
