#!/bin/bash
###############################################################################
#               PROTEIN-Peptide MD PREPARATION PIPELINE (GROMACS)
###############################################################################

############################ USER SETTINGS ####################################

PROTEIN="Protein.pdb"
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

# Protein-pep combined group
PROTEIN_GROUP=1

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

local order=(protein box solvate ions em index nvt npt md)

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

# ============================================================
# AUTOMATIC PROTEIN–PEPTIDE INDEX GENERATION
# ============================================================

detect_protein_peptide_groups() {

    echo
    echo "============================================================"
    echo " Detecting Protein and Peptide Atom Ranges from em.gro"
    echo "============================================================"

    if [[ ! -f em.gro ]]; then
        echo "ERROR: em.gro not found."
        exit 1
    fi

    # --------------------------------------------------------
    # Standard amino-acid residue names
    # --------------------------------------------------------
    is_amino_acid() {
        case "$1" in
            ALA|ARG|ASN|ASP|CYS|GLN|GLU|GLY|HIS|ILE|LEU|LYS|MET|PHE|PRO|SER|THR|TRP|TYR|VAL)
                return 0
                ;;
            HID|HIE|HIP|HSD|HSE|HSP|ASH|GLH|CYM|CYN|CYS2)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }

    # --------------------------------------------------------
    # Parse GRO file
    #
    # Detect the first large residue-number reset.
    #
    # Example:
    #
    # Protein:
    # 298...
    # 299...
    #
    # Peptide:
    # 67...
    # 68...
    # 69...
    #
    # --------------------------------------------------------

    DETECTION=$(awk '
    NR > 2 {

        # GRO fixed-width fields
        resnr   = int(substr($0,1,5))
        resname = substr($0,6,5)
        atomnr  = int(substr($0,16,5))

        gsub(/^[ \t]+|[ \t]+$/, "", resname)

        if (have_previous) {

            drop = previous_resnr - resnr

            # Detect residue-number reset
            # Only consider meaningful backward jumps.
            if (drop > 10 && !found_boundary) {

                protein_end_atom  = previous_atomnr
                peptide_start_atom = atomnr

                protein_end_res   = previous_resnr
                peptide_start_res = resnr

                found_boundary = 1
            }
        }

        # ----------------------------------------------------
        # Once peptide starts, determine its final atom.
        # Continue while residues are amino acids.
        # ----------------------------------------------------

        if (found_boundary && atomnr >= peptide_start_atom) {

            if (resname == "SOL" ||
                resname == "WAT" ||
                resname == "HOH" ||
                resname == "NA"  ||
                resname == "CL"  ||
                resname == "K"   ||
                resname == "CA"  ||
                resname == "MG") {

                if (!peptide_end_found) {
                    peptide_end_atom = previous_atomnr
                    peptide_end_res  = previous_resnr
                    peptide_end_found = 1
                }

            } else {

                # Standard amino-acid residue
                if (resname == "ALA" ||
                    resname == "ARG" ||
                    resname == "ASN" ||
                    resname == "ASP" ||
                    resname == "CYS" ||
                    resname == "GLN" ||
                    resname == "GLU" ||
                    resname == "GLY" ||
                    resname == "HIS" ||
                    resname == "ILE" ||
                    resname == "LEU" ||
                    resname == "LYS" ||
                    resname == "MET" ||
                    resname == "PHE" ||
                    resname == "PRO" ||
                    resname == "SER" ||
                    resname == "THR" ||
                    resname == "TRP" ||
                    resname == "TYR" ||
                    resname == "VAL" ||
                    resname == "HID" ||
                    resname == "HIE" ||
                    resname == "HIP" ||
                    resname == "HSD" ||
                    resname == "HSE" ||
                    resname == "HSP" ||
                    resname == "ASH" ||
                    resname == "GLH" ||
                    resname == "CYM" ||
                    resname == "CYN" ||
                    resname == "CYS2") {

                    peptide_end_atom = atomnr
                    peptide_end_res  = resnr
                }
            }
        }

        previous_resnr = resnr
        previous_atomnr = atomnr
        have_previous = 1
    }

    END {

        if (!found_boundary) {
            print "ERROR"
            exit 1
        }

        if (!peptide_end_found) {
            # Peptide continued until the end of the GRO file
            peptide_end_atom = previous_atomnr
            peptide_end_res  = previous_resnr
        }

        printf "%d %d %d %d %d %d\n",
               protein_end_atom,
               peptide_start_atom,
               peptide_end_atom,
               protein_end_res,
               peptide_start_res,
               peptide_end_res
    }
    ' em.gro)

    if [[ "$DETECTION" == "ERROR" ]]; then
        echo
        echo "ERROR: Could not detect a protein-peptide boundary."
        echo "Check residue numbering in em.gro."
        exit 1
    fi

    read \
        PROTEIN_END_ATOM \
        PEPTIDE_START_ATOM \
        PEPTIDE_END_ATOM \
        PROTEIN_END_RES \
        PEPTIDE_START_RES \
        PEPTIDE_END_RES <<< "$DETECTION"

    echo
    echo "Protein:"
    echo "  Last residue : $PROTEIN_END_RES"
    echo "  Last atom    : $PROTEIN_END_ATOM"

    echo
    echo "Peptide:"
    echo "  First residue: $PEPTIDE_START_RES"
    echo "  First atom   : $PEPTIDE_START_ATOM"
    echo "  Last residue : $PEPTIDE_END_RES"
    echo "  Last atom    : $PEPTIDE_END_ATOM"

    echo
    echo "Detected atom ranges:"
    echo "  Protein = 1-$PROTEIN_END_ATOM"
    echo "  Peptide = $PEPTIDE_START_ATOM-$PEPTIDE_END_ATOM"
    
}    
    
###############################################################################
# CREATE INDEX FILES
###############################################################################

CURRENT_STEP="index"

if step_enabled index
then

    banner "CREATING INDEX FILES"

    ###########################################################################
    # Automatically detect Protein and Peptide ranges
    ###########################################################################

    detect_protein_peptide_groups

    ###########################################################################
    # NORMAL INDEX
    #
    # index.ndx
    #
    # This is the index used for:
    #
    # NVT
    # NPT
    # Production MD
    #
    # We preserve the standard GROMACS groups.
    ###########################################################################

    echo
    echo -e "${BLUE}Creating normal index.ndx${NC}"

    printf "q\n" | \
    gmx make_ndx \
        -f em.gro \
        -o index.ndx

    echo
    echo -e "${GREEN}✓ Normal index.ndx generated${NC}"

    ###########################################################################
    # CUSTOM PROTEIN-PEPTIDE INDEX
    #
    # custom_index.ndx
    #
    # IMPORTANT:
    #
    # This uses ATOM selections.
    #
    # It is NOT used by NVT/NPT/MD.
    #
    ###########################################################################

    echo
    echo -e "${BLUE}Creating custom_index.ndx${NC}"

    printf \
"a 1-%s
name 18 Protein
a %s-%s
name 19 Peptide
q
" \
        "$PROTEIN_END_ATOM" \
        "$PEPTIDE_START_ATOM" \
        "$PEPTIDE_END_ATOM" |
    gmx make_ndx \
        -f em.gro \
        -o protein_pep_index.ndx

    echo
    echo -e "${GREEN}✓ protein_pep_index.ndx generated${NC}"

    ###########################################################################
    # SUMMARY
    ###########################################################################

    echo
    echo "============================================================"
    echo " INDEX GENERATION SUMMARY"
    echo "============================================================"

    echo
    echo "Normal index:"
    echo "  index.ndx"
    echo "  Used for NVT/NPT/Production MD"

    echo
    echo "Custom index:"
    echo "  protein_pep_index.ndx"
    echo "  Used for Protein-Peptide analysis"

    echo
    echo "Custom Protein:"
    echo "  Atoms 1-$PROTEIN_END_ATOM"

    echo
    echo "Custom Peptide:"
    echo "  Atoms $PEPTIDE_START_ATOM-$PEPTIDE_END_ATOM"

    echo
    echo "============================================================"

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
