#!/bin/bash
###############################################################################
#             PROTEIN–SAM–SUBSTRATE MD PREPARATION PIPELINE
#                         GROMACS
#
# Protein + SAM/cofactor are processed together using pdb2gmx.
# Substrate is treated as the external ligand and has its own topology.
###############################################################################

############################ USER SETTINGS ####################################

# IMPORTANT:
# This PDB must contain BOTH the protein and SAM/cofactor.
# SAM must be named/residue/atom-formatted so that pdb2gmx can recognize it.

PROTEIN="M121V_Co.pdb"
IGNORE_H=" -ignh"
TERMINI=" -ter"

# Substrate only
SUBSTRATE="DMW1.pdb"

# Substrate topology
SUB_A="DMW_a.itp" 
SUB_M="DMW_m.itp"

TOP="topol.top"

# Box
BOXTYPE="cubic"
BOXDIST="1.0"

# Position restraints for SUBSTRATE
POSRES_FORCE="1000 1000 1000"

# Heavy atoms of substrate
SUBSTRATE_INDEX_SELECTION="0 & ! a H*"

# These are determined from make_ndx output.
# IMPORTANT: verify these interactively if necessary.
SUBSTRATE_POSRES_GROUP=3


###############################################################################
# INDEX SETTINGS
###############################################################################

# Protein + SAM combined group
# These numbers may differ depending on your pdb2gmx/make_ndx output.
PROTEIN_GROUP=1
SAM_GROUP=13
SUBSTRATE_GROUP=14

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

RESUME_NVT=false
RESUME_NPT=false
RESUME_MD=false

###############################################################################
# RESTART FROM ANY STEP
# protein
# substrate
# merge
# topology
# box
# solvate
# ions
# em
# posre_substrate
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

###############################################################################
# FUNCTIONS
###############################################################################

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

local order=(
protein
substrate
merge
topology
box
solvate
ions
em
posre_substrate
index
nvt
npt
md
)

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
# STEP 1
# PROTEIN PREPARATION
###############################################################################

CURRENT_STEP="protein"

if step_enabled protein
then

banner "PROTEIN PREPARATION" 

gmx pdb2gmx -f "$PROTEIN" -o protein_Co.gro -p "$TOP" $IGNORE_H  $TERMINI 


fi

###############################################################################
# STEP 2
# SUBSTRATE PREPARATION
###############################################################################

CURRENT_STEP="substrate"

if step_enabled substrate
then

banner "SUBSTRATE PREPARATION"

run "Converting substrate PDB to GRO" \
gmx editconf \
-f "$SUBSTRATE" \
-o DMW.gro

echo 
echo -e "${GREEN}✓ Substrate GRO generated.${NC}" 

fi

###############################################################################
# STEP 3
# MERGE PROTEIN + SAM + SUBSTRATE
###############################################################################

CURRENT_STEP="merge"

if step_enabled merge
then

banner "PROTEIN + SAM + DMW COMPLEX GENERATION"

echo
echo -e "${BLUE}Combining Protein + SAM with DMW...${NC}"

# Number of atoms in Protein + SAM
C=$(sed -n '2p' protein_Co.gro)

# Number of substrate atoms
S=$(sed -n '2p' DMW.gro)

# Total atoms
TOTAL=$((C+S))

echo "Protein + SAM atoms : $C"
echo "Substrate atoms     : $S"
echo "Total atoms         : $TOTAL"

# Header
head -1 protein_Co.gro > complex_DMW.gro

# Total atom count
echo "$TOTAL" >> complex_DMW.gro

# Protein + SAM coordinates
tail -n +3 protein_Co.gro | head -n -1 >> complex_DMW.gro

# Substrate coordinates
tail -n +3 DMW.gro | head -n -1 >> complex_DMW.gro

# Use box from protein + SAM
tail -n 1 protein_Co.gro >> complex_DMW.gro

echo -e "${GREEN}✓ Protein + SAM + DMW complex generated.${NC}"

fi

###############################################################################
# STEP 4
# SUBSTRATE TOPOLOGY
###############################################################################

CURRENT_STEP="topology"


if step_enabled topology
then

banner "SUBSTRATE TOPOLOGY PREPARATION"


echo
echo -e "${BLUE}Substrate topology files:${NC}"

echo "    $SUB_A"
echo "    $SUB_M"


# DETERMINE MOLECULE NAME

SUBSTRATE_MOL=$(awk '
/\[ *moleculetype *\]/ {
    getline

    while ($0 ~ /^[[:space:]]*;/ || $0 ~ /^[[:space:]]*$/)
        getline

    print $1

    exit
}
' "$SUB_M")


if [ -z "$SUBSTRATE_MOL" ]
then

echo
echo -e "${RED}ERROR: Could not determine substrate molecule name.${NC}"

echo
echo "Check the [ moleculetype ] section in:"
echo "$SUB_M"

exit 1

fi


echo
echo -e "${GREEN}Substrate moleculetype detected:${NC}"

echo "$SUBSTRATE_MOL"


# INCLUDE SUBSTRATE A

echo
echo -e "${BLUE}Adding $SUB_A to topol.top${NC}"


if ! grep -q "$SUB_A" "$TOP"
then

    sed -i \
    '/forcefield.itp/a #include "'"$SUB_A"'"' \
    "$TOP"

fi


# INCLUDE SUBSTRATE M

echo
echo -e "${BLUE}Adding $SUB_M to topol.top${NC}"


if ! grep -q "$SUB_M" "$TOP"
then

    # Prefer placing the molecule topology before water topology.

    if grep -q "Include water topology" "$TOP"
    then

        sed -i \
        '/Include water topology/i\
#include "'"$SUB_M"'"\
' "$TOP"

    else

        # Fallback:
        # Add it before the [ system ] section.

        sed -i \
        '/^\[ *system *\]/i\
#include "'"$SUB_M"'"\
' "$TOP"

    fi

fi

# ADD SUBSTRATE TO MOLECULES

echo
echo -e "${BLUE}Adding substrate to [ molecules ]${NC}"


if grep -q "^[[:space:]]*$SUBSTRATE_MOL[[:space:]]" "$TOP"
then

echo
echo -e "${YELLOW}$SUBSTRATE_MOL already exists in [ molecules ].${NC}"

else

awk -v mol="$SUBSTRATE_MOL" '

BEGIN {
    in_molecules=0
    added=0
}


/^\[ *molecules *\]/ {

    in_molecules=1

    print

    next
}


/^\[/ {

    if (in_molecules && !added) {

        print mol "    1"

        added=1

    }

    in_molecules=0

    print

    next
}


{

    print

}


END {

    if (in_molecules && !added) {

        print mol "    1"

    }

}

' "$TOP" > "${TOP}.tmp"


mv "${TOP}.tmp" "$TOP"


fi


echo
echo -e "${GREEN}✓ Substrate topology added to topol.top.${NC}"


###############################################################################
# DISPLAY MOLECULE SECTION
###############################################################################

echo
echo -e "${BLUE}[ molecules ] currently contains:${NC}"


awk '
/^\[ *molecules *\]/ {
    flag=1
    next
}

flag && /^\[/ {
    exit
}

flag {
    print
}
' "$TOP"


fi

###############################################################################
# STEP 5
# BOX
###############################################################################

CURRENT_STEP="box"

if step_enabled box
then

banner "BOX GENERATION"

run "Creating simulation box" \
gmx editconf \
-f complex_DMW.gro \
-o boxed.gro \
-c \
-d "$BOXDIST" \
-bt "$BOXTYPE"

fi

###############################################################################
# STEP 6
# SOLVATION
###############################################################################

CURRENT_STEP="solvate"

if step_enabled solvate
then

banner "SOLVATION"

run "Adding water molecules" \
gmx solvate \
-cp boxed.gro \
-cs spc216.gro \
-o solv.gro \
-p "$TOP"

fi

###############################################################################
# STEP 7
# ADD IONS
###############################################################################

CURRENT_STEP="ions"

if step_enabled ions
then

banner "ADDING IONS"

run "Preparing ions" \
gmx grompp \
-f ions.mdp \
-c solv.gro \
-p "$TOP" \
-o ions.tpr \
-maxwarn 10

echo
echo -e "${BLUE}>>> Adding ions${NC}"

echo SOL | \
gmx genion \
-s ions.tpr \
-o solv_ions.gro \
-p "$TOP" \
-pname NA \
-nname CL \
-neutral | tee -a run.log

if [ ${PIPESTATUS[0]} -ne 0 ]
then

echo -e "${RED}Ion addition failed.${NC}"
exit 1

fi

echo -e "${GREEN}✓ Ions added.${NC}"

fi

###############################################################################
# STEP 8
# ENERGY MINIMIZATION
###############################################################################

CURRENT_STEP="em"

if step_enabled em
then

banner "ENERGY MINIMIZATION"

run "Generating EM input" \
gmx grompp \
-f em.mdp \
-c solv_ions.gro \
-p "$TOP" \
-o em.tpr \
-maxwarn 10

run "Running Energy Minimization" \
gmx mdrun \
-deffnm em \
-v

fi

###############################################################################
# STEP 9
# SUBSTRATE POSITION RESTRAINTS
###############################################################################

CURRENT_STEP="posre_substrate"

if step_enabled posre_substrate
then

banner "SUBSTRATE POSITION RESTRAINTS"

echo
echo -e "${BLUE}Creating substrate index.${NC}"

# Create substrate index.
#
# 0 = System
# 1 = Other
# 2 = QUR1
# 3 = System_&_!H*
#
printf "%s\nq\n" \
"$SUBSTRATE_INDEX_SELECTION" | \
gmx make_ndx \
-f DMW.gro \
-o index_DMW.ndx


echo
echo -e "${BLUE}Generating substrate position restraints.${NC}"

# ---------------------------------------------------------------------------
# IMPORTANT
#
# The substrate molecule is QUR1 in your current system.
#
# Instead of relying on a hard-coded numerical group, explicitly find QUR1.
# ---------------------------------------------------------------------------

SUBSTRATE_GROUP_NUMBER=$(awk '
/^\[/ {
    name=$0
    gsub(/[\[\]]/, "", name)
    gsub(/^[ \t]+|[ \t]+$/, "", name)

    getline

    if (name == "DMW1") {
        print NR
        exit
    }
}
' index_DMW.ndx)

# More reliable method:
SUBSTRATE_GROUP_NUMBER=$(awk '
/^\[/ {
    group=$0
    gsub(/[\[\]]/, "", group)
    gsub(/^[ \t]+|[ \t]+$/, "", group)

    if (group == "DMW1") {
        found=1
        exit
    }

    found=0
}
END {
    if (found)
        print "2"
}
' index_DMW.ndx)


# ---------------------------------------------------------------------------
# Since QUR1 is group 2 in your current substrate index:
# ---------------------------------------------------------------------------

SUBSTRATE_GROUP_NUMBER=2


echo
echo "Substrate group: DMW1"
echo "Substrate group number: $SUBSTRATE_GROUP_NUMBER"


echo "$SUBSTRATE_GROUP_NUMBER" | \
gmx genrestr \
-f DMW.gro \
-n index_DMW.ndx \
-o posre_DMW.itp \
-fc $POSRES_FORCE | tee -a run.log


if [ ${PIPESTATUS[0]} -ne 0 ]
then

    echo
    echo -e "${RED}Substrate position restraint generation failed.${NC}"

    exit 1

fi


echo
echo -e "${GREEN}✓ Substrate position restraints generated.${NC}"


###############################################################################
# ADD POSITION RESTRAINTS TO substrate_m.itp
###############################################################################

if [ ! -f "$SUB_M" ]
then

    echo
    echo -e "${RED}ERROR: Substrate topology file is not defined.${NC}"

    echo "SUB_M = '$SUB_M'"

    exit 1

fi


if [ ! -f "posre_DMW.itp" ]
then

    echo
    echo -e "${RED}ERROR: posre_DMW.itp was not generated.${NC}"

    exit 1

fi


if ! grep -q "POSRES_DMW" "$SUB_M"
then

cat >> "$SUB_M" << EOF


; ======================================================================
; SUBSTRATE POSITION RESTRAINTS
; ======================================================================

#ifdef POSRES_SUBSTRATE
#include "posre_DMW.itp"
#endif
EOF

fi


echo
echo -e "${GREEN}✓ Substrate position restraints linked to $SUB_M.${NC}"


fi

###############################################################################
# STEP 10
# INDEX
###############################################################################

CURRENT_STEP="index"

if step_enabled index
then

banner "CREATING INDEX FILE"

echo
echo -e "${BLUE}Creating Protein + SAM + Substrate index${NC}"

echo
echo "Protein   : group $PROTEIN_GROUP"
echo "SAM       : group $SAM_GROUP"
echo "Substrate : group $SUBSTRATE_GROUP"
echo

gmx make_ndx \
-f em.gro \
-o index.ndx << EOF
$PROTEIN_GROUP | $SAM_GROUP | $SUBSTRATE_GROUP
name $COMPLEX_GROUP Protein_SAM_DMW1
q
EOF

echo
echo -e "${GREEN}✓ Combined Protein + SAM + Substrate group created.${NC}"

echo
echo "Combined group:"
echo "  Protein + SAM + DMW1 = group $COMPLEX_GROUP"

fi

###############################################################################
# STEP 11
# NVT
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
-v | tee -a run.log

else

run "Generating NVT input" \
gmx grompp \
-f nvt.mdp \
-c em.gro \
-r em.gro \
-p "$TOP" \
-n index.ndx \
-o nvt.tpr \
-maxwarn 10

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
# STEP 12
# NPT
###############################################################################

CURRENT_STEP="npt"

if step_enabled npt
then

banner "NPT EQUILIBRATION"

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

run "Generating NPT input" \
gmx grompp \
-f npt.mdp \
-c nvt.gro \
-r nvt.gro \
-p "$TOP" \
-n index.ndx \
-o npt.tpr \
-maxwarn 10

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
# STEP 13
# PRODUCTION MD
###############################################################################

CURRENT_STEP="md"

if step_enabled md
then

banner "PRODUCTION MOLECULAR DYNAMICS"

if [ "$RESUME_MD" = true ] && [ -f "md.cpt" ]
then

echo -e "${YELLOW}Checkpoint detected.${NC}"
echo -e "${GREEN}Resuming Production MD from checkpoint...${NC}"

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
echo -e "${GREEN}Starting Production MD...${NC}"
echo -e "${CYAN}Checkpoint interval: 5 minutes${NC}"

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
echo -e "${YELLOW}To resume:${NC}"
echo -e "${GREEN}RESUME_MD=true${NC}"
echo -e "${GREEN}START_FROM=\"md\"${NC}"

exit 1

fi

echo
echo -e "${GREEN}✓ Production MD Completed${NC}"

fi
