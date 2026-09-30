#!/bin/bash

###############################################################################
#            GROMACS POST-MD ANALYSIS PIPELINE
#
#                 PROTEIN + SAM + SUBSTRATE
#
# Analysis:
#   1. Center / PBC correction
#   2. Protein RMSD
#   3. SAM RMSD
#   4. Substrate RMSD
#   5. Protein RMSF
#   6. Radius of gyration
#   7. SASA
#   8. Protein-SAM H-bonds
#   9. Protein-Substrate H-bonds
#  10. SAM-Substrate H-bonds
#  11. H-bond occupancy
#  12. Movie generation
#  13. Post-MD structure extraction
#
###############################################################################


############################ USER SETTINGS ####################################

TPR="md_new.tpr"
XTC="md.xtc"
INDEX="index.ndx"

OUTDIR="Analysis"


###############################################################################
# RESTART CONTROL
###############################################################################

# Available options:
#
# center
# rmsd
# rmsf
# rg
# sasa
# hbond
# occupancy
# movie
# postpdb

START_FROM="center"


###############################################################################
# GROUP SELECTIONS
###############################################################################

# IMPORTANT:
# Check your actual group numbers using:
#
# gmx make_ndx -f md_new.tpr -n index.ndx
#
# and modify the numbers below.


PROTEIN_GROUP=1

BACKBONE_GROUP=4

SAM_GROUP=13

SUBSTRATE_GROUP=14


# Group containing:
# Protein + SAM + Substrate
#
# Create this group in index.ndx if you do not already have one.

COMPLEX_GROUP=24


# Center trajectory around protein

CENTER_GROUP=$PROTEIN_GROUP

# Write complete system after centering

OUTPUT_GROUP=0


# Movie

MOVIE_GROUP=$COMPLEX_GROUP


###############################################################################
# H-BOND OCCUPANCY SETTINGS
###############################################################################

OCCUPANCY_SCRIPT="occupancy.pl"


###############################################################################
# FRAME EXTRACTION
###############################################################################

# Set true if using ns

USE_NS=true


# ns

START_TIME_NS=100
END_TIME_NS=100


# ps

START_TIME_PS=100000
END_TIME_PS=100000


###############################################################################
# COLORS
###############################################################################

GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"
YELLOW="\033[1;33m"
NC="\033[0m"


###############################################################################
# INITIALIZATION
###############################################################################

set -e

mkdir -p "$OUTDIR"

: > analysis.log


###############################################################################
# BANNER FUNCTION
###############################################################################

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


###############################################################################
# RUN FUNCTION
###############################################################################

run(){

DESC="$1"
shift

echo -e "${BLUE}>>> $DESC${NC}"

"$@" 2>&1 | tee -a analysis.log

if [ ${PIPESTATUS[0]} -ne 0 ]
then

    echo
    echo -e "${RED}ERROR : $DESC${NC}"
    echo
    echo -e "${YELLOW}Restart using:${NC}"
    echo -e "${GREEN}START_FROM=\"$CURRENT_STEP\"${NC}"

    exit 1

fi

echo
echo -e "${GREEN}✓ Completed${NC}"
echo

}


###############################################################################
# RESTART FUNCTION
###############################################################################

step_enabled(){

local order=(
center
rmsd
rmsf
rg
sasa
hbond
occupancy
movie
postpdb
)

local start=-1
local current=-1


for i in "${!order[@]}"
do

    [[ "${order[$i]}" == "$START_FROM" ]] && start=$i
    [[ "${order[$i]}" == "$1" ]] && current=$i

done


if [ "$start" -eq -1 ]
then

    echo "ERROR: Invalid START_FROM value: $START_FROM"
    exit 1

fi


[[ $current -ge $start ]]

}


###############################################################################
###############################################################################
#                              CENTERING
###############################################################################
###############################################################################

CURRENT_STEP="center"

if step_enabled center
then

banner "RECENTERING AND PBC CORRECTION"


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


echo
echo -e "${GREEN}Centered trajectory generated: md_center.xtc${NC}"

fi


###############################################################################
###############################################################################
#                                RMSD
###############################################################################
###############################################################################

CURRENT_STEP="rmsd"

if step_enabled rmsd
then

banner "RMSD ANALYSIS"


###############################################################################
# Protein RMSD
###############################################################################

echo -e "${BLUE}Protein Backbone RMSD${NC}"


printf "%s\n%s\n" \
"$BACKBONE_GROUP" \
"$BACKBONE_GROUP" | \
gmx rms \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/rmsd_protein.xvg" \
-tu ns | tee -a analysis.log


echo
echo -e "${GREEN}Protein RMSD Completed${NC}"


###############################################################################
# SAM RMSD
#
# Fit trajectory using protein backbone.
# Calculate RMSD of SAM.
###############################################################################

echo
echo -e "${BLUE}SAM RMSD relative to protein${NC}"


printf "%s\n%s\n" \
"$SAM_GROUP" \
"$SAM_GROUP" | \
gmx rms \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/rmsd_SAM.xvg" \
-tu ns | tee -a analysis.log


echo
echo -e "${GREEN}SAM RMSD Completed${NC}"


###############################################################################
# Substrate RMSD
#
# Fit trajectory using protein backbone.
# Calculate RMSD of substrate.
###############################################################################

echo
echo -e "${BLUE}Substrate RMSD relative to protein${NC}"


printf "%s\n%s\n" \
"$SUBSTRATE_GROUP" \
"$SUBSTRATE_GROUP" | \
gmx rms \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/rmsd_substrate.xvg" \
-tu ns | tee -a analysis.log


echo
echo -e "${GREEN}Substrate RMSD Completed${NC}"


fi


###############################################################################
###############################################################################
#                                RMSF
###############################################################################
###############################################################################

CURRENT_STEP="rmsf"

if step_enabled rmsf
then

banner "PROTEIN RMSF ANALYSIS"


printf "%s\n%s\n" \
"$BACKBONE_GROUP" \
"$BACKBONE_GROUP" | \
gmx rmsf \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/rmsf_protein.xvg" \
-res | tee -a analysis.log


echo
echo -e "${GREEN}Protein RMSF Completed${NC}"

fi


###############################################################################
###############################################################################
#                       RADIUS OF GYRATION
###############################################################################
###############################################################################

CURRENT_STEP="rg"

if step_enabled rg
then

banner "RADIUS OF GYRATION"


printf "%s\n" \
"$PROTEIN_GROUP" | \
gmx gyrate \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/gyrate.xvg" | tee -a analysis.log


echo
echo -e "${GREEN}Radius of Gyration Completed${NC}"

fi


###############################################################################
###############################################################################
#                                SASA
###############################################################################
###############################################################################

CURRENT_STEP="sasa"

if step_enabled sasa
then

banner "SOLVENT ACCESSIBLE SURFACE AREA"


printf "%s\n" \
"$PROTEIN_GROUP" | \
gmx sasa \
-s "$TPR" \
-f md_center.xtc \
-o "$OUTDIR/sasa.xvg" | tee -a analysis.log


echo
echo -e "${GREEN}SASA Completed${NC}"

fi


###############################################################################
###############################################################################
#                         HYDROGEN BONDS
###############################################################################
###############################################################################

CURRENT_STEP="hbond"

if step_enabled hbond
then

banner "HYDROGEN BOND ANALYSIS"


###############################################################################
# Protein - SAM
###############################################################################

echo
echo -e "${BLUE}Protein - SAM Hydrogen Bonds${NC}"


printf "%s\n%s\n" \
"$PROTEIN_GROUP" \
"$SAM_GROUP" | \
gmx hbond \
-s "$TPR" \
-f md_center.xtc \
-n "$INDEX" \
-num "$OUTDIR/hbond_protein_SAM.xvg" \
-hbn "$OUTDIR/hbond_protein_SAM.ndx" \
-hbm "$OUTDIR/hbond_protein_SAM_map.xpm" | tee -a analysis.log


echo
echo -e "${GREEN}Protein-SAM H-bond analysis completed${NC}"


###############################################################################
# Protein - Substrate
###############################################################################

echo
echo -e "${BLUE}Protein - Substrate Hydrogen Bonds${NC}"


printf "%s\n%s\n" \
"$PROTEIN_GROUP" \
"$SUBSTRATE_GROUP" | \
gmx hbond \
-s "$TPR" \
-f md_center.xtc \
-n "$INDEX" \
-num "$OUTDIR/hbond_protein_substrate.xvg" \
-hbn "$OUTDIR/hbond_protein_substrate.ndx" \
-hbm "$OUTDIR/hbond_protein_substrate_map.xpm" | tee -a analysis.log


echo
echo -e "${GREEN}Protein-Substrate H-bond analysis completed${NC}"


###############################################################################
# SAM - Substrate
###############################################################################

echo
echo -e "${BLUE}SAM - Substrate Hydrogen Bonds${NC}"


printf "%s\n%s\n" \
"$SAM_GROUP" \
"$SUBSTRATE_GROUP" | \
gmx hbond \
-s "$TPR" \
-f md_center.xtc \
-n "$INDEX" \
-num "$OUTDIR/hbond_SAM_substrate.xvg" \
-hbn "$OUTDIR/hbond_SAM_substrate.ndx" \
-hbm "$OUTDIR/hbond_SAM_substrate_map.xpm" | tee -a analysis.log


echo
echo -e "${GREEN}SAM-Substrate H-bond analysis completed${NC}"


fi


###############################################################################
###############################################################################
#                           MOVIE GENERATION
###############################################################################
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
-n "$INDEX" \
-o "$OUTDIR/movie.pdb" \
-dt 100 \
-fit progressive | tee -a analysis.log


echo
echo -e "${GREEN}Movie Generated Successfully${NC}"

fi


###############################################################################
###############################################################################
#                              FINISHED
###############################################################################
###############################################################################

banner "ANALYSIS COMPLETED"


echo -e "${GREEN}"
echo "Analysis completed successfully."
echo
echo "Results saved in:"
echo
echo "    $OUTDIR/"
echo
echo "Main outputs:"
echo
echo " Protein RMSD       : rmsd_protein.xvg"
echo " SAM RMSD           : rmsd_SAM.xvg"
echo " Substrate RMSD     : rmsd_substrate.xvg"
echo " Protein RMSF       : rmsf_protein.xvg"
echo " Radius of gyration : gyrate.xvg"
echo " SASA               : sasa.xvg"
echo
echo " H-bonds:"
echo "   Protein-SAM"
echo "   Protein-Substrate"
echo "   SAM-Substrate"
echo
echo " Occupancy:"
echo "   occupancy_protein_SAM.txt"
echo "   occupancy_protein_substrate.txt"
echo "   occupancy_SAM_substrate.txt"
echo
echo " Post-MD structure:"
echo "   protein_SAM_substrate_postMD.pdb"
echo
echo -e "${NC}"
