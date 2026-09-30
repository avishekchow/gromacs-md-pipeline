# Restart and checkpoint handling

The preparation scripts expose restart controls for major workflow stages and production checkpoints.

Before resuming:

1. Confirm that the expected checkpoint file exists.
2. Confirm that the corresponding `.tpr`, coordinate, topology, and input files are still consistent.
3. Review `START_FROM` and the relevant `RESUME_*` settings.
4. Do not mix checkpoints from unrelated systems or simulation protocols.

Checkpoint/restart behavior is system- and script-specific; consult the preparation script before use.
