# Enzyme-cofactor-substrate MD workflow — Preparation

enzyme system containing a SAM/cofactor component and an external substrate.

## Script

**md_prep.sh** is the main preparation workflow.

## Before running

Review the user settings at the beginning of **md_prep.sh**, including input structure names, topology files, index groups, box settings, restart options, and simulation parameters.

This workflow expects the required GROMACS `.mdp` files to be available in the working setup. The repository does not invent or silently replace research-specific simulation parameters.

1. Enter the preparation directory.
2. Place/verify the required input structure and topology files.
3. Ensure the MDP files are available in the expected location.
4. Run md_prep.sh from the preparation directory.
5. Review the user-configurable parameters before execution.

## Run

```bash
chmod +x md_prep.sh
./md_prep.sh
```

## Important

Validate the generated topology, index groups, energy-minimized structure, and equilibration output before relying on a production trajectory.
