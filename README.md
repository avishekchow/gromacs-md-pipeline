# GROMACS MD Pipeline

Reusable GROMACS-based molecular dynamics workflows for four common biomolecular system types:

1. Protein-only
2. Protein-ligand
3. Protein-peptide
4. Enzyme-cofactor-substrate

The repository separates **MD preparation** from **post-MD analysis** and is designed to be cloned and run locally by each user. Generated simulation files are created on the user's own machine; they are not written to this GitHub repository automatically.

## Repository structure

```text
gromacs-md-pipeline/
├── README.md
├── LICENSE
├── CITATION.cff
├── .gitignore
├── pipelines/
│   ├── 01_protein_only/
│   ├── 02_protein_ligand/
│   ├── 03_protein_peptide/
│   └── 04_enzyme_cofactor_substrate/
├── common/
├── scripts/
├── docs/
└── examples/
```

## Current workflow coverage

### 01 — Protein-only

Preparation includes protein preparation, topology generation, box construction, solvation, ion addition, energy minimization, index generation, NVT, NPT, and production MD, with restart/checkpoint controls present in the workflow script.

Post-MD analysis includes trajectory centering/PBC processing, RMSD, RMSF, radius of gyration, SASA, movie generation, and post-MD structure extraction.

### 02 — Protein-ligand

Preparation includes protein and ligand preparation, complex construction, ligand topology handling, ligand position restraints, solvation, ion addition, energy minimization, index generation, NVT, NPT, and production MD.

Post-MD analysis includes protein and ligand RMSD, protein RMSF, radius of gyration, SASA, protein-ligand hydrogen-bond analysis, movie generation, and post-MD structure extraction.

### 03 — Protein-peptide

Preparation includes protein-peptide system setup, solvation, ion addition, energy minimization, automatic protein/peptide boundary detection, generation of standard and custom index files, NVT, NPT, and production MD.

Post-MD analysis includes protein and peptide RMSD, protein RMSF, radius of gyration, SASA, protein-peptide hydrogen-bond analysis, movie generation, and post-MD structure extraction.

### 04 — Enzyme-cofactor-substrate

The current workflow is designed around a protein + SAM/cofactor + external substrate system. Protein and SAM/cofactor are handled together during protein preparation, while the substrate is treated as an external component with its own topology and position restraints.

Post-MD analysis includes protein, SAM/cofactor, and substrate RMSD, protein RMSF, radius of gyration, SASA, and pairwise hydrogen-bond analyses for protein-cofactor, protein-substrate, and cofactor-substrate interactions.

## Requirements

- Linux/Unix environment
- Bash
- GROMACS installed and available as `gmx`
- Appropriate input structures
- Force-field parameters compatible with the selected system
- Required ligand/cofactor/substrate topology files where applicable
- GROMACS `.mdp` files appropriate for the simulation protocol

Check your installation with:

```bash
./scripts/check_dependencies.sh
```

## Getting started

Clone the repository:

```bash
git clone https://github.com/avishekchow/gromacs-md-pipeline.git
cd gromacs-md-pipeline
```

Choose the workflow matching your system. For example:

```bash
cd pipelines/01_protein_only/preparation
chmod +x md_prep.sh
./md_prep.sh
```

Before running a workflow, **open the script and review the user settings**. Current scripts intentionally retain system-specific filenames and index-group assumptions from the research workflows from which they were developed.

## Important: input and output locations

The scripts run locally in the directory where they are executed. A user cloning this repository gets their own copy. Simulation outputs such as `.gro`, `.tpr`, `.xtc`, `.edr`, `.cpt`, `.xvg`, and related files remain on that user's machine unless they explicitly add and push them to another repository.

For research projects, it is recommended to keep large trajectories and checkpoints outside the source-code repository.

## Restart and checkpointing

The preparation workflows include configurable restart controls for major preparation/equilibration/production stages. Review the `RESUME_*` and `START_FROM` settings in the relevant script before restarting a workflow.

See `docs/restart_and_checkpoint.md` for guidance.

## Reproducibility

The repository contains workflow scripts and documentation. Simulation-specific inputs, force-field files, ligand parameters, trajectories, and analysis outputs should be archived with the corresponding research project or data repository rather than committed indiscriminately to this source repository.

## Scope of the current release

This repository is being organized from existing, tested research scripts. The current release preserves those scripts rather than inventing additional analysis modules. Additional modular analysis scripts such as PCA, DSSP, contact maps, distance analysis, and catalytic-distance analysis can be added after they are implemented and validated against the corresponding workflows.

## Author

**Avishek Chowdhury**  
Computational Biology & Bioinformatics  
Molecular Modeling | Molecular Dynamics | Machine Learning

GitHub: https://github.com/avishekchow

## Citation

If you use these workflows in research, please cite this repository and the associated publication(s), where applicable. See `CITATION.cff`.
