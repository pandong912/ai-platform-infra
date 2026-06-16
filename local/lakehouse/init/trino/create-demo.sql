CREATE SCHEMA IF NOT EXISTS iceberg.video;

DROP TABLE IF EXISTS iceberg.video.training_videos;

CREATE TABLE iceberg.video.training_videos (
  video_id varchar,
  source_uri varchar,
  task varchar,
  label_status varchar,
  duration_seconds double,
  frame_count bigint,
  resolution varchar,
  captured_at timestamp(6),
  created_at timestamp(6)
)
WITH (
  format = 'PARQUET'
);

INSERT INTO iceberg.video.training_videos VALUES
  (
    'vid-0001',
    's3://raw-videos/action/vid-0001.mp4',
    'action-recognition',
    'labeled',
    12.5,
    375,
    '1920x1080',
    TIMESTAMP '2026-06-01 10:00:00.000000',
    current_timestamp
  ),
  (
    'vid-0002',
    's3://raw-videos/tracking/vid-0002.mp4',
    'object-tracking',
    'reviewing',
    24.0,
    720,
    '1280x720',
    TIMESTAMP '2026-06-01 11:30:00.000000',
    current_timestamp
  ),
  (
    'vid-0003',
    's3://raw-videos/segmentation/vid-0003.mp4',
    'video-segmentation',
    'unlabeled',
    8.8,
    264,
    '3840x2160',
    TIMESTAMP '2026-06-02 09:15:00.000000',
    current_timestamp
  );

SELECT * FROM iceberg.video.training_videos ORDER BY video_id;

SELECT committed_at, snapshot_id, operation
FROM iceberg.video."training_videos$snapshots"
ORDER BY committed_at DESC;
