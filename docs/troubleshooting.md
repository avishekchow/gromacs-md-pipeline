# Troubleshooting

## `gmx` not found

Run:

```bash
./scripts/check_dependencies.sh
```

Then activate/load the GROMACS installation used by your system.

## Missing input files

Use:

```bash
./scripts/validate_inputs.sh file1 file2 file3
```

## Wrong index group

Index numbers can change depending on the input structure, force field, residue names, and `make_ndx` output. Review the groups selected by the workflow rather than assuming that a group number from another system is valid.

## Ligand/substrate topology errors

Verify that the ligand/substrate `.itp` files, atom names, residue names, molecule names, and topology includes are consistent with the coordinate file and the generated topology.

## Production restart problems

Check the checkpoint file, `.tpr`, working directory, and restart settings. Do not reuse a checkpoint from a different simulation system or protocol.
