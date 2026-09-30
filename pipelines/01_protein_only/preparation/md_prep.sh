#!/bin/bash
###############################################################################
#               PROTEIN MD PREPARATION PIPELINE (GROMACS)
###############################################################################

############################ USER SETTINGS ####################################

PROTEIN="best_model_single.pdb"
IGNORE_H=" -ignh"
TERMINI=" -ter"

TOP="topol.top"

BOXTYPE="cubic"
BOXDIST="1.0"

#ION_CONC="0.15"
THREADS=8

###############################################################################
# INDEX SELECTIONS
###############################################################################

# Protein-Ligand combined group
PROTEIN_GROUP=1

###############################################################################
# CUSTOM INDEX SETTINGS
###############################################################################

# false = Protein index
# true  = Protein-Protein / Protein-Peptide index
CUSTOM_INDEX=false

CHAIN1_ATOMS="1-3575"
CHAIN2_ATOMS="3576-3642"

CHAIN1_GROUP=18
CHAIN2_GROUP=19

CHAIN1_NAME="Chain_A"
CHAIN2_NAME="Chain_B"

###############################################################################
# RESUME SETTINGS
###############################################################################

# Automatically resume NVT, NPT or MD if a checkpoint (.cpt) file exists.
# If false, a new simulation will always be started.
# Resume NVT from nvt.cpt if available
RESUME_NVT=false

# Resume NPT from npt.cpt if available
RESUME_NPT=false

# Resume Production MD from md.cpt if available
RESUME_MD=true

###############################################################################
# Restart from any step
#
# protein
# topology
# box
# solvate
# ions
# em
# index
# nvt
# npt
# md
###############################################################################

START_FROM="protein"

###############################################################################

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"
YELLOW="\033[1;33m"
NC="\033[0m"

: > run.log

banner(){

echo

echo -e "${CYAN}======================================================================${NC}"
echo -e "${MAGENTA}                     $1${NC}"
echo -e "${CYAN}======================================================================${NC}"

{
echo "======================================================================"
echo "$1"
echo "======================================================================"
} >> run.log

}

run(){

DESC="$1"
shift

echo
echo -e "${BLUE}>>> $DESC${NC}"

"$@" 2>&1 | tee -a run.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then

echo
echo -e "${RED}ERROR during : $DESC${NC}"

echo
echo -e "${YELLOW}Correct the error and restart from:${NC}"
echo -e "${GREEN}START_FROM=\"$CURRENT_STEP\"${NC}"

exit 1

fi

echo -e "${GREEN}✓ $DESC Completed${NC}"

}

step_enabled(){

local order=(protein topology box solvate ions em index nvt npt md)

local start=-1
local current=-1

for i in "${!order[@]}"
do

[[ "${order[$i]}" == "$START_FROM" ]] && start=$i

[[ "${order[$i]}" == "$1" ]] && current=$i

done

[[ $current -ge $start ]]

}

###############################################################################
# PROTEIN PREPARATION
###############################################################################

CURRENT_STEP="protein"

if step_enabled protein
then

banner "PROTEIN PREPARATION" 

gmx pdb2gmx -f "$PROTEIN" -o protein_processed.gro -p "$TOP" $TERMINI
#$IGNORE_H 

fi


###############################################################################
# TOPOLOGY CHECK
###############################################################################

CURRENT_STEP="topology"

if step_enabled topology
then

    banner "TOPOLOGY CHECK"

    if [ ! -f "$TOP" ]; then
        echo -e "${RED}ERROR: $TOP not found.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Protein topology found: $TOP${NC}"

fi

###############################################################################
# BOX GENERATION
###############################################################################

CURRENT_STEP="box"

if step_enabled box
then

banner "BOX GENERATION"
run "Creating simulation box" \
gmx editconf -f protein_processed.gro -o boxed.gro -c -d "$BOXDIST" -bt "$BOXTYPE"

fi

###############################################################################
# SOLVATION
###############################################################################

CURRENT_STEP="solvate"

if step_enabled solvate
then

banner "SOLVATION"
run "Adding water molecules" \
gmx solvate -cp boxed.gro -cs spc216.gro -o solv.gro -p "$TOP"

fi

###############################################################################
# ADDING IONS
###############################################################################

CURRENT_STEP="ions"

if step_enabled ions
then

banner "ADDING IONS"
run "Preparing ions" \
gmx grompp -f ions.mdp -c solv.gro -p "$TOP" -o ions.tpr -maxwarn 10

echo SOL | gmx genion -s ions.tpr -o solv_ions.gro -p "$TOP" -pname NA -nname CL -neutral | tee -a run.log

fi

###############################################################################
# ENERGY MINIMIZATION
###############################################################################

CURRENT_STEP="em"

if step_enabled em
then

banner "ENERGY MINIMIZATION"
run "Generating EM input" \
gmx grompp -f em.mdp -c solv_ions.gro -p "$TOP" -o em.tpr -maxwarn 10
run "Running Energy Minimization" \
gmx mdrun -deffnm em -v 

fi

###############################################################################
# CREATE INDEX FILE
###############################################################################

CURRENT_STEP="index"

if step_enabled index
then

banner "CREATING INDEX FILE"

if [ "$CUSTOM_INDEX" = false ]
then

echo -e "${BLUE}Creating Protein-Ligand Index${NC}"

printf "%s | %s\nq\n" \
"$PROTEIN_GROUP" | \
gmx make_ndx -f em.gro -o index.ndx

else

echo -e "${BLUE}Creating Custom Protein-Protein/Protein-Peptide Index${NC}"

printf "a %s\nname 18 %s\na %s\nname 19 %s\nq\n" \
"$CHAIN1_ATOMS" \
"$CHAIN1_GROUP" \
"$CHAIN1_NAME" \
"$CHAIN2_ATOMS" \
"$CHAIN2_GROUP" \
"$CHAIN2_NAME" | \
gmx make_ndx -f em.gro -o index.ndx

fi

echo
echo -e "${GREEN}Index File Generated Successfully${NC}"

fi

###############################################################################
# NVT EQUILIBRATION
###############################################################################

CURRENT_STEP="nvt"

if step_enabled nvt
then

banner "NVT EQUILIBRATION"

if [ "$RESUME_NVT" = true ] && [ -f "nvt.cpt" ]
then

    echo -e "${YELLOW}Checkpoint detected.${NC}"
    echo -e "${GREEN}Resuming NVT from checkpoint...${NC}"

    gmx mdrun \
    -deffnm nvt \
    -cpi nvt.cpt \
    -append \
    -v  | tee -a run.log

else

    run "Generating NVT input" \
    gmx grompp -f nvt.mdp -c em.gro -r em.gro -p "$TOP" -n index.ndx -o nvt.tpr -maxwarn 10

    echo
    echo -e "${GREEN}Starting a new NVT simulation...${NC}"

    gmx mdrun \
    -deffnm nvt \
    -v | tee -a run.log

fi

if [ ${PIPESTATUS[0]} -ne 0 ]
then

    echo
    echo -e "${RED}ERROR during NVT simulation${NC}"

    echo
    echo -e "${YELLOW}Correct the error and restart from:${NC}"
    echo -e "${GREEN}START_FROM=\"nvt\"${NC}"

    exit 1

fi

echo -e "${GREEN}✓ NVT Completed${NC}"

fi

###############################################################################
# NPT EQUILIBRATION
###############################################################################

CURRENT_STEP="npt"

if step_enabled npt
then

banner "NPT EQUILIBRATION"
echo
echo -e "${BLUE}>>> Running NPT${NC}"

if [ "$RESUME_NPT" = true ] && [ -f "npt.cpt" ]
then

    echo -e "${YELLOW}Checkpoint detected.${NC}"
    echo -e "${GREEN}Resuming NPT from checkpoint...${NC}"

    gmx mdrun \
    -deffnm npt \
    -cpi npt.cpt \
    -append \
    -v | tee -a run.log

else

    run "Generating NVT input" \
    gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -p "$TOP" -n index.ndx -o npt.tpr -maxwarn 10

    echo
    echo -e "${GREEN}Starting a new NPT simulation...${NC}"

    gmx mdrun \
    -deffnm npt \
    -v | tee -a run.log

fi

if [ ${PIPESTATUS[0]} -ne 0 ]
then

    echo
    echo -e "${RED}ERROR during NPT simulation${NC}"

    echo
    echo -e "${YELLOW}Correct the error and restart from:${NC}"
    echo -e "${GREEN}START_FROM=\"npt\"${NC}"

    exit 1

fi

echo -e "${GREEN}✓ NPT Completed${NC}"

fi 

###############################################################################
# PRODUCTION MOLECULAR DYNAMICS
###############################################################################

CURRENT_STEP="md"

if step_enabled md
then

banner "PRODUCTION MOLECULAR DYNAMICS"
echo
echo -e "${BLUE}>>> Running Production MD${NC}"

if [ "$RESUME_MD" = true ] && [ -f "md.cpt" ]
then

    echo -e "${YELLOW}Checkpoint detected.${NC}"
    echo -e "${GREEN}Resuming Production MD from checkpoint...${NC}"
    echo -e "${CYAN}Checkpoint interval: 5 minutes${NC}"
    echo

    gmx mdrun \
    -deffnm md \
    -cpi md.cpt \
    -append \
    -cpt 5 \
    -v | tee -a run.log

else

    run "Generating MD input" \
    gmx grompp \
    -f md.mdp \
    -c npt.gro \
    -r npt.gro \
    -p "$TOP" \
    -n index.ndx \
    -o md.tpr \
    -maxwarn 10

    echo
    echo -e "${GREEN}Starting a new Production MD simulation...${NC}"
    echo -e "${CYAN}Checkpoint interval: 5 minutes${NC}"
    echo

    gmx mdrun \
    -deffnm md \
    -cpt 5 \
    -v | tee -a run.log

fi

if [ ${PIPESTATUS[0]} -ne 0 ]
then

    echo
    echo -e "${RED}ERROR during Production MD simulation${NC}"

    echo
    echo -e "${YELLOW}To resume from the latest checkpoint:${NC}"
    echo -e "${GREEN}RESUME_MD=true${NC}"
    echo -e "${GREEN}START_FROM=\"md\"${NC}"

    exit 1

fi

echo
echo -e "${GREEN}✓ Production MD Completed${NC}"

fi

###############################################################################
# SIMULATION COMPLETED
###############################################################################

banner "SIMULATION COMPLETED"
echo -e "${GREEN}All stages completed successfully.${NC}"

