# Installation and prerequisites

## Required software

The workflows require a Linux/Unix environment with Bash and a working GROMACS installation exposing the `gmx` command.

Check the installation with:

```bash
./scripts/check_dependencies.sh
```

System information can be displayed with:

```bash
./scripts/system_info.sh
```

The exact GROMACS version used for a publication should be recorded with the simulation project because software versions and force-field components can affect reproducibility.
