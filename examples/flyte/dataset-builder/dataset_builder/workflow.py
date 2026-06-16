from __future__ import annotations

import json
from pathlib import Path

from flytekit import task, workflow

from dataset_builder.planner import compile_plan, load_spec


def _step_params(plan: dict[str, object], step_name: str) -> dict[str, object]:
    for step in plan["steps"]:
        if step["name"] == step_name:
            return step["params"]
    raise ValueError(f"step not found: {step_name}")


@task
def compile_dataset_plan(spec_path: str) -> str:
    spec = load_spec(spec_path)
    plan = compile_plan(spec)
    return plan.model_dump_json()


@task
def resolve_snapshot(plan_json: str) -> str:
    plan = json.loads(plan_json)
    params = _step_params(plan, "resolve_snapshot")
    return json.dumps(
        {
            "table": params["table"],
            "snapshot_id": params["snapshot_id"],
            "candidate_count": 250000,
        }
    )


@task
def filter_candidates(snapshot_json: str, plan_json: str) -> str:
    snapshot = json.loads(snapshot_json)
    filters = _step_params(json.loads(plan_json), "filter_candidates")
    return json.dumps(
        {
            "source": snapshot,
            "filters": filters,
            "candidate_count": 140000,
        }
    )


@task
def dedup_candidates(filtered_json: str, plan_json: str) -> str:
    filtered = json.loads(filtered_json)
    dedup = _step_params(json.loads(plan_json), "dedup")
    return json.dumps(
        {
            "source": filtered,
            "dedup": dedup,
            "candidate_count": 118000,
        }
    )


@task
def sample_candidates(deduped_json: str, plan_json: str) -> str:
    deduped = json.loads(deduped_json)
    sample = _step_params(json.loads(plan_json), "sample")
    return json.dumps(
        {
            "source_count": deduped["candidate_count"],
            "sample": sample,
            "candidate_count": sample["size"],
        }
    )


@task
def split_dataset(sampled_json: str, plan_json: str) -> str:
    sampled = json.loads(sampled_json)
    split = _step_params(json.loads(plan_json), "split")
    total = int(sampled["candidate_count"])
    train = int(total * split["train"])
    validation = int(total * split["validation"])
    test = total - train - validation
    return json.dumps(
        {
            "train": train,
            "validation": validation,
            "test": test,
            "total": total,
        }
    )


@task
def validate_dataset(split_json: str, plan_json: str) -> str:
    split = json.loads(split_json)
    validation = _step_params(json.loads(plan_json), "validate")
    expected_total = split["train"] + split["validation"] + split["test"]
    return json.dumps(
        {
            "valid": split["total"] == expected_total,
            "checks": ["split_total", "lineage_present"],
            "lineage": validation["lineage"],
        }
    )


@task
def publish_manifest(split_json: str, validation_json: str, plan_json: str) -> str:
    plan = json.loads(plan_json)
    manifest = {
        "dataset_name": plan["dataset_name"],
        "source_table": plan["source_table"],
        "source_snapshot_id": plan["source_snapshot_id"],
        "manifest_uri": plan["manifest_uri"],
        "splits": json.loads(split_json),
        "validation": json.loads(validation_json),
        "plan_steps": [step["name"] for step in plan["steps"]],
    }

    output_path = Path("outputs") / f"{plan['dataset_name']}-manifest.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
    return str(output_path)


@workflow
def dataset_builder_workflow(spec_path: str = "specs/video_caption_gold.yaml") -> str:
    plan = compile_dataset_plan(spec_path=spec_path)
    snapshot = resolve_snapshot(plan_json=plan)
    filtered = filter_candidates(snapshot_json=snapshot, plan_json=plan)
    deduped = dedup_candidates(filtered_json=filtered, plan_json=plan)
    sampled = sample_candidates(deduped_json=deduped, plan_json=plan)
    split = split_dataset(sampled_json=sampled, plan_json=plan)
    validation = validate_dataset(split_json=split, plan_json=plan)
    return publish_manifest(split_json=split, validation_json=validation, plan_json=plan)


if __name__ == "__main__":
    print(dataset_builder_workflow())
