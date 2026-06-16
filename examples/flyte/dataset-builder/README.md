# Dataset Builder Flyte Example

This example shows how a platform-neutral Dataset Spec can be compiled by a small Planner into a Flyte workflow input for a video training Gold dataset build.

The workflow is intentionally lightweight: it writes manifest-like JSON files instead of launching real Spark or Ray jobs. In production, each task boundary can be replaced with SparkApplication, RayJob, or container tasks while keeping the Dataset Spec contract stable.

## Local Dry Run

```bash
cd examples/flyte/dataset-builder
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m dataset_builder.planner specs/video_caption_gold.yaml
python -m dataset_builder.workflow
```

## Flyte Registration

Build and push an image that contains this directory, then register the workflow:

```bash
pyflyte register \
  --project dataset-platform \
  --domain development \
  --image ghcr.io/REPLACE_WITH_ORG/dataset-builder:dev \
  dataset_builder/workflow.py
```
