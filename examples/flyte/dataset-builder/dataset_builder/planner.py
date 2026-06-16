from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

from dataset_builder.schema import DatasetPlan, DatasetSpec, PlanStep


def load_spec(path: str | Path) -> DatasetSpec:
    with Path(path).open("r", encoding="utf-8") as spec_file:
        payload = yaml.safe_load(spec_file)
    return DatasetSpec.model_validate(payload)


def compile_plan(spec: DatasetSpec) -> DatasetPlan:
    dataset_name = spec.metadata.name
    source_ref = "source_snapshot"
    filtered_ref = "filtered_candidates"
    deduped_ref = "deduped_candidates"
    sampled_ref = "sampled_candidates"
    split_ref = "dataset_splits"
    validation_ref = "validation_report"

    return DatasetPlan(
        dataset_name=dataset_name,
        source_table=spec.source.table,
        source_snapshot_id=spec.source.snapshot_id,
        manifest_uri=spec.outputs.manifest_uri,
        steps=[
            PlanStep(
                name="resolve_snapshot",
                task_type="container",
                outputs=[source_ref],
                params={
                    "table": spec.source.table,
                    "snapshot_id": spec.source.snapshot_id,
                },
            ),
            PlanStep(
                name="filter_candidates",
                task_type="spark",
                inputs=[source_ref],
                outputs=[filtered_ref],
                params=spec.selection.filters.model_dump(by_alias=True),
            ),
            PlanStep(
                name="dedup",
                task_type="spark",
                inputs=[filtered_ref],
                outputs=[deduped_ref],
                params=spec.selection.dedup.model_dump(),
            ),
            PlanStep(
                name="sample",
                task_type="ray",
                inputs=[deduped_ref],
                outputs=[sampled_ref],
                params=spec.selection.sample.model_dump(),
            ),
            PlanStep(
                name="split",
                task_type="container",
                inputs=[sampled_ref],
                outputs=[split_ref],
                params=spec.split.model_dump(),
            ),
            PlanStep(
                name="validate",
                task_type="container",
                inputs=[split_ref],
                outputs=[validation_ref],
                params={
                    "lineage": spec.outputs.lineage.model_dump(by_alias=True),
                },
            ),
            PlanStep(
                name="publish",
                task_type="container",
                inputs=[split_ref, validation_ref],
                outputs=[spec.outputs.manifest_uri],
                params={
                    "manifest_uri": spec.outputs.manifest_uri,
                    "dataset_name": dataset_name,
                },
            ),
        ],
    )


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: python -m dataset_builder.planner <spec.yaml>")

    spec = load_spec(sys.argv[1])
    plan = compile_plan(spec)
    print(json.dumps(plan.model_dump(), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
