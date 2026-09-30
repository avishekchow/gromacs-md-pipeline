# MDP files

Place the GROMACS parameter files required by **md_prep.sh** in this directory or update the script to point to your parameter-file location.

Expected stages commonly referenced by the workflows include:

- `ions.mdp`
- `em.mdp`
- `nvt.mdp`
- `npt.mdp`
- `md.mdp`

The repository currently does **not** provide newly invented MDP parameter values. Use the validated MDP files from your simulation protocol and document the GROMACS version and force-field configuration used.
