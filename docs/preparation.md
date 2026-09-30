# MD preparation

Each preparation workflow follows the system-specific sequence implemented in its `md_prep.sh` script.

Before execution, review:

- Input structure names
- Topology and parameter files
- Force-field selections
- Box settings
- Index-group assumptions
- Position-restraint settings for ligand/substrate systems
- NVT/NPT/production parameters
- Restart/checkpoint settings

The scripts currently preserve research-specific defaults. They should therefore be treated as templates that must be adapted and validated for each new system.
