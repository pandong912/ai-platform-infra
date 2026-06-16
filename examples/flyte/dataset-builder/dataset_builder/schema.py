from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator


class DatasetMetadata(BaseModel):
    name: str
    owner: str
    description: str = ""


class DatasetSource(BaseModel):
    table: str
    snapshot_id: str = Field(alias="snapshotId")


class FilterSpec(BaseModel):
    min_duration_seconds: int = Field(alias="minDurationSeconds", ge=0)
    max_duration_seconds: int = Field(alias="maxDurationSeconds", gt=0)
    min_resolution_height: int = Field(alias="minResolutionHeight", ge=0)
    allowed_licenses: list[str] = Field(alias="allowedLicenses")

    @model_validator(mode="after")
    def validate_duration_range(self) -> "FilterSpec":
        if self.min_duration_seconds > self.max_duration_seconds:
            raise ValueError("minDurationSeconds cannot exceed maxDurationSeconds")
        return self


class DedupSpec(BaseModel):
    key: str
    threshold: float = Field(ge=0.0, le=1.0)


class SampleSpec(BaseModel):
    strategy: Literal["random", "stratified", "balanced"]
    size: int = Field(gt=0)
    strata: list[str] = []


class SelectionSpec(BaseModel):
    filters: FilterSpec
    dedup: DedupSpec
    sample: SampleSpec


class SplitSpec(BaseModel):
    train: float = Field(gt=0.0, lt=1.0)
    validation: float = Field(gt=0.0, lt=1.0)
    test: float = Field(gt=0.0, lt=1.0)

    @model_validator(mode="after")
    def validate_split_sum(self) -> "SplitSpec":
        total = self.train + self.validation + self.test
        if abs(total - 1.0) > 0.0001:
            raise ValueError("train + validation + test must equal 1.0")
        return self


class LineageSpec(BaseModel):
    datahub_dataset_urn: str = Field(alias="datahubDatasetUrn")


class OutputSpec(BaseModel):
    manifest_uri: str = Field(alias="manifestUri")
    lineage: LineageSpec


class DatasetSpec(BaseModel):
    api_version: str = Field(alias="apiVersion")
    kind: Literal["DatasetSpec"]
    metadata: DatasetMetadata
    source: DatasetSource
    selection: SelectionSpec
    split: SplitSpec
    outputs: OutputSpec


class PlanStep(BaseModel):
    name: str
    task_type: Literal["container", "spark", "ray"]
    inputs: list[str] = []
    outputs: list[str] = []
    params: dict[str, object] = {}


class DatasetPlan(BaseModel):
    dataset_name: str
    source_table: str
    source_snapshot_id: str
    manifest_uri: str
    steps: list[PlanStep]
