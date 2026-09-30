# Post-MD analysis

The current analysis workflows are coordinated shell pipelines rather than independent one-analysis-per-file modules.

Depending on the system, they perform trajectory processing and calculate RMSD, RMSF, radius of gyration, SASA, hydrogen-bond interactions, trajectory movies, and post-MD structures. The protein-ligand, protein-peptide, and enzyme-cofactor-substrate workflows additionally analyze the corresponding interacting components.

Future modular scripts may be added once each analysis has been independently implemented and validated.
