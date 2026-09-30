#!/bin/bash
###############################################################################
#                 GROMACS POST-MD ANALYSIS PIPELINE
#               (CENTERING + RMSD + RMSF)
###############################################################################

############################ USER SETTINGS ####################################

TPR="md_0_1.tpr"
XTC="md_0_1_center.xtc"

# Resume from:
# center
# rmsd
# rmsf
# rg
# sasa
# hbond
# movie
# postpdb
START_FROM="center"

########################### GROUP SELECTIONS ##################################

CENTER_GROUP=1          # Protein
OUTPUT_GROUP=0          # System

BACKBONE_GROUP=4

LIGAND_GROUP=13

PROTEIN_GROUP=1

MOVIE_GROUP=22
POSTMD_GROUP=22

###############################################################################
# H-BOND OCCUPANCY
###############################################################################

HBOND_GROUP=22

OCCUPANCY_SCRIPT="occupancy.pl"

HBOND_INDEX="index_hbond.ndx"

STRUCTURE="protein_ligand_structure.pdb"

# Extract frame
# If using picoseconds
START_TIME_PS=100000
END_TIME_PS=100000
# If using nanoseconds
START_TIME_NS=100
END_TIME_NS=100

# true = use ns
USE_NS=true

############################ OUTPUT FOLDERS ###################################

OUTDIR="Analysis"

###############################################################################

set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"
YELLOW="\033[1;33m"
NC="\033[0m"

mkdir -p "$OUTDIR"

: > analysis.log

banner(){

echo
echo -e "${CYAN}====================================================================${NC}"
echo -e "${MAGENTA}                     $1${NC}"
echo -e "${CYAN}====================================================================${NC}"

{
echo "===================================================================="
echo "$1"
echo "===================================================================="
} >> analysis.log

}

run(){

DESC="$1"
shift

echo -e "${BLUE}>>> $DESC${NC}"

"$@" 2>&1 | tee -a analysis.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then

echo
echo -e "${RED}ERROR : $DESC${NC}"
echo
echo -e "${YELLOW}Restart from:${NC}"
echo -e "${GREEN}START_FROM=\"$CURRENT_STEP\"${NC}"
exit 1

fi

echo -e "${GREEN}✓ Completed${NC}"
echo

}

step_enabled(){

local order=(center rmsd rmsf rg sasa hbond movie postpdb)

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
# CENTERING
###############################################################################

CURRENT_STEP="center"

if step_enabled center
then

banner "RECENTERING AND REWRAPPING"

printf "%s\n%s\n" \
"$CENTER_GROUP" \
"$OUTPUT_GROUP" | \
gmx trjconv \
-s "$TPR" \
-f "$XTC" \
-o md_center.xtc \
-center \
-pbc mol \
-ur compact | tee -a analysis.log

fi

###############################################################################
# RMSD
###############################################################################

CURRENT_STEP="rmsd"

if step_enabled rmsd
then

banner "RMSD ANALYSIS"

echo -e "${BLUE}Protein RMSD${NC}"

printf "%s\n%s\n" \
"$BACKBONE_GROUP" \
"$BACKBONE_GROUP" | \
gmx rms \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/rmsd_protein.xvg" | tee -a analysis.log

echo -e "${GREEN}Protein RMSD Completed${NC}"

echo

echo -e "${BLUE}Ligand RMSD${NC}"

printf "%s\n%s\n" \
"$LIGAND_GROUP" \
"$LIGAND_GROUP" | \
gmx rms \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/rmsd_ligand.xvg" | tee -a analysis.log

echo -e "${GREEN}Ligand RMSD Completed${NC}"

fi

###############################################################################
# RMSF
###############################################################################

CURRENT_STEP="rmsf"

if step_enabled rmsf
then

banner "RMSF ANALYSIS"

printf "%s\n%s\n" \
"$BACKBONE_GROUP" \
"$BACKBONE_GROUP" | \
gmx rmsf \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/rmsf.xvg" \
-res | tee -a analysis.log

echo -e "${GREEN}RMSF Completed${NC}"

fi

###############################################################################
# RADIUS OF GYRATION
###############################################################################

CURRENT_STEP="rg"

if step_enabled rg
then

banner "RADIUS OF GYRATION"

printf "%s\n" \
"$PROTEIN_GROUP" | \
gmx gyrate \
-s "$TPR" \
-f "$XTC" \
-o "$OUTDIR/gyrate.xvg" | tee -a analysis.log

echo
echo -e "${GREEN}Radius of Gyration Completed${NC}"

fi

###############################################################################
# SASA
###############################################################################

CURRENT_STEP="sasa"

if step_enabled sasa
then

banner "SOLVENT ACCESSIBLE SURFACE AREA"

printf "%s\n" \
"$PROTEIN_GROUP" | \
gmx sasa \
-s "$TPR" \
-f "$XTC" \
-o "$OUTDIR/sasa.xvg" | tee -a analysis.log

echo
echo -e "${GREEN}SASA Completed${NC}"

fi

###############################################################################
# HYDROGEN BONDS
###############################################################################

CURRENT_STEP="hbond"

if step_enabled hbond
then

banner "HYDROGEN BOND ANALYSIS"

printf "%s\n%s\n" \
"$PROTEIN_GROUP" \
"$LIGAND_GROUP" | \
gmx hbond \
-s "$TPR" \
-f "$XTC" \
-num "$OUTDIR/hbond.xvg" \
-hbn "$OUTDIR/hbond.ndx" \
-hbm "$OUTDIR/hbond_map.xpm" | tee -a analysis.log

echo
echo -e "${GREEN}Hydrogen Bond Analysis Completed${NC}"

fi

###############################################################################
# MOVIE GENERATION
###############################################################################

CURRENT_STEP="movie"

if step_enabled movie
then

banner "MOVIE GENERATION"

printf "%s\n%s\n" \
"$MOVIE_GROUP" \
"$MOVIE_GROUP" | \
gmx trjconv \
-f md_center.xtc \
-s "$TPR" \
-n index.ndx \
-o "$OUTDIR/movie.pdb" \
-dt 100 \
-fit progressive | tee -a analysis.log

echo
echo -e "${GREEN}Movie Generated Successfully${NC}"

fi

###############################################################################
# POST-MD PDB
###############################################################################

CURRENT_STEP="postpdb"
# Extract frame

# If using picoseconds
START_TIME_PS=100000
END_TIME_PS=100000
if step_enabled postpdb
then

banner "POST-MD PDB"

if [ "$USE_NS" = true ]
then

printf "%s\n%s\n" \
"$POSTMD_GROUP" \
"$POSTMD_GROUP" | \
gmx trjconv \
-f md_center.xtc \
-s "$TPR" \
-n index.ndx \
-o "$OUTDIR/protein_ligand.pdb" \
-tu ns \
-b "$START_TIME_NS" \
-e "$END_TIME_NS" | tee -a analysis.log

else

printf "%s\n%s\n" \
"$POSTMD_GROUP" \
"$POSTMD_GROUP" | \
gmx trjconv \
-f md_center.xtc \
-s "$TPR" \
-n index.ndx \
-o "$OUTDIR/protein_ligand.pdb" \
-b "$START_TIME_PS" \
-e "$END_TIME_PS" | tee -a analysis.log

fi

echo
echo -e "${GREEN}Post-MD PDB Generated Successfully${NC}"

fi

###############################################################################

banner "ANALYSIS COMPLETED"

echo -e "${GREEN}"
echo "Results saved in:"
echo
echo "$OUTDIR/"
echo -e "${NC}"
