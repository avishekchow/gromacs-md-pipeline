# Pipeline overview

The repository is organized by molecular system type.

| Pipeline | Preparation | Current post-MD analysis |
|---|---|---|
| Protein-only | topology, box, solvation, ions, EM, index, NVT, NPT, production MD | PBC/centering, RMSD, RMSF, Rg, SASA, movie, post-MD structure |
| Protein-ligand | protein/ligand preparation, complex, ligand topology/restraints, box, solvation, ions, EM, index, NVT, NPT, production MD | protein/ligand RMSD, RMSF, Rg, SASA, H-bonds, movie, post-MD structure |
| Protein-peptide | protein/peptide setup, automatic protein/peptide boundary detection, index generation, box, solvation, ions, EM, NVT, NPT, production MD | protein/peptide RMSD, RMSF, Rg, SASA, H-bonds, movie, post-MD structure |
| Enzyme-cofactor-substrate | protein/cofactor handling, substrate topology/restraints, complex construction, box, solvation, ions, EM, index, NVT, NPT, production MD | protein/cofactor/substrate RMSD, RMSF, Rg, SASA, pairwise H-bonds, movie/post-MD outputs |

The current repository does not claim separate PCA, DSSP, contact-map, or catalytic-distance modules unless and until those scripts are implemented and validated.
