#!/bin/bash
###############################################################################
#               PROTEIN-LIGAND MD PREPARATION PIPELINE (GROMACS)
###############################################################################

############################ USER SETTINGS ####################################

PROTEIN="protein.pdb"
IGNORE_H=" -ignh"
TERMINI=" -ter"
LIGAND="lig.pdb"

LIG_A="lig_a.itp"
LIG_M="lig_m.itp"

TOP="topol.top"

BOXTYPE="cubic"
BOXDIST="1.0"

#ION_CONC="0.15"
THREADS=8

###############################################################################
# INDEX SELECTIONS
###############################################################################

# Ligand heavy atoms for position restraints
LIGAND_INDEX_SELECTION="0 & ! a H*"

# Group created above (usually group 3)
LIGAND_POSRES_GROUP=3

# Protein-Ligand combined group
PROTEIN_GROUP=1
LIGAND_GROUP=13

# Position restraint force constant
POSRES_FORCE="1000 1000 1000"

###############################################################################
# CUSTOM INDEX SETTINGS
###############################################################################

# false = Protein-Ligand index
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
RESUME_MD=false

###############################################################################
# Restart from any step
#
# protein
# ligand
# complex
# topology
# box
# solvate
# ions
# em
# posre_lig
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

local order=(protein ligand complex topology box solvate ions em posre_lig index nvt npt md)

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

gmx pdb2gmx -f "$PROTEIN" -o protein_processed.gro -p "$TOP" $IGNORE_H 
#$TERMINI 

fi

###############################################################################
# LIGAND PREPARATION
###############################################################################

CURRENT_STEP="ligand"

if step_enabled ligand
then

banner "LIGAND PREPARATION"

run "Converting ligand PDB to GRO" \
gmx editconf -f "$LIGAND" -o ligand.gro

fi

###############################################################################
# PROTEIN-LIGAND COMPLEX GENERATION
###############################################################################

CURRENT_STEP="complex"

if step_enabled complex
then

banner "PROTEIN-LIGAND COMPLEX GENERATION"

P=$(sed -n '2p' protein_processed.gro)
L=$(sed -n '2p' ligand.gro)
TOTAL=$((P+L))

head -1 protein_processed.gro > complex.gro
echo "$TOTAL" >> complex.gro
tail -n +3 protein_processed.gro | head -n -1 >> complex.gro
tail -n +3 ligand.gro | head -n -1 >> complex.gro
tail -n 1 protein_processed.gro >> complex.gro

fi

###############################################################################
# TOPOLOGY PREPARATION
###############################################################################

CURRENT_STEP="topology"

if step_enabled topology
then

banner "TOPOLOGY PREPARATION"

# Insert lig_a.itp after the forcefield include
grep -q "$LIG_A" "$TOP" || \
sed -i '/forcefield.itp/a #include "'"$LIG_A"'"' "$TOP"

# Insert lig_m.itp before the water topology
grep -q "$LIG_M" "$TOP" || \
sed -i '/Include water topology/i\
#include "'"$LIG_M"'"\
' "$TOP"

MOL=$(awk '/\[ moleculetype \]/{getline;getline;print $1;exit}' "$LIG_M")

grep -q "^${MOL}[[:space:]]" "$TOP" || \
sed -i '/^Protein_chain_A[[:space:]]\+1/a '"$MOL"'    1' "$TOP"

fi

###############################################################################
# BOX GENERATION
###############################################################################

CURRENT_STEP="box"

if step_enabled box
then

banner "BOX GENERATION"
run "Creating simulation box" \
gmx editconf -f complex.gro -o boxed.gro -c -d "$BOXDIST" -bt "$BOXTYPE"

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
# LIGAND POSITION RESTRAINTS
###############################################################################

CURRENT_STEP="posre_lig"

if step_enabled posre_lig
then

banner "LIGAND POSITION RESTRAINTS"

printf "%s\nq\n" "$LIGAND_INDEX_SELECTION" | \
gmx make_ndx -f ligand.gro -o index_lig.ndx

echo -e "${BLUE}>>> Generating ligand position restraints${NC}"
echo "$LIGAND_POSRES_GROUP" | \
gmx genrestr \
-f ligand.gro \
-n index_lig.ndx \
-o posre_lig.itp \
-fc $POSRES_FORCE | tee -a run.log

if [ ${PIPESTATUS[1]} -ne 0 ]; then
    echo -e "${RED}Ligand position restraint generation failed.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Ligand position restraints generated.${NC}"

# Insert ligand position restraints after lig_m.itp
grep -q "POSRES_LIG" "$TOP" || \
sed -i '/'"$LIG_M"'/a\
\
; Ligand position restraints\
#ifdef POSRES_LIG\
#include "posre_lig.itp"\
#endif' "$TOP"

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
"$PROTEIN_GROUP" \
"$LIGAND_GROUP" | \
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

    gmx mdrun \
    -deffnm md \
    -cpi md.cpt \
    -append \
    -v | tee -a run.log

else
    
    run "Generating MD input" \
    gmx grompp -f md.mdp -c npt.gro -r npt.gro -p "$TOP" -n index.ndx -o md.tpr -maxwarn 10

    echo
    echo -e "${GREEN}Starting a new Production MD simulation...${NC}"

    gmx mdrun \
    -deffnm md \
    -v | tee -a run.log

fi

if [ ${PIPESTATUS[0]} -ne 0 ]
then

    echo
    echo -e "${RED}ERROR during Production MD simulation${NC}"

    echo
    echo -e "${YELLOW}Correct the error and restart from:${NC}"
    echo -e "${GREEN}START_FROM=\"md\"${NC}"

    exit 1

fi

echo -e "${GREEN}✓ Production MD Completed${NC}"

fi
 
banner "SIMULATION COMPLETED"
echo -e "${GREEN}All stages completed successfully.${NC}"
