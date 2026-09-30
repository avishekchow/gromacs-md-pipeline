# Enzyme-cofactor-substrate MD workflow — Analysis

enzyme system containing a SAM/cofactor component and an external substrate.

## Script

**analysis.sh** is the coordinated post-MD analysis workflow for this system type.

## Run

Run the analysis from a directory containing the trajectory and topology files expected by the script, after reviewing the input filenames and analysis-group settings near the beginning of **analysis.sh**.

```bash
chmod +x analysis.sh
./analysis.sh
```

## Outputs

Outputs depend on the workflow and include trajectory-processing files, structural/dynamical metrics, interaction analyses where applicable, visualization/movie files, and extracted post-MD structures.
