#!/bin/bash
# Factor Xa example (c) by Google LLC
# Derived from Justin Lemhul (http://www.mdtutorials.com) - licensed under CC-BY-4.0 &
# Alessandra Villa (https://tutorials.gromacs.org/) - licensed under CC-BY-4.0
#
# Factor Xa example is licensed under a
# Creative Commons Attribution 4.0 International (CC BY 4.0) License.
# See <https://creativecommons.org/licenses/by/4.0/>.

#SBATCH -N 1
#SBATCH --ntasks-per-node 1
#SBATCH --partition gpu
#SBATCH --gpus 1

PDB_FILE=1FJS.pdb
PROTEIN="${PDB_FILE%.*}"

echo $PDB_FILE
echo $PROTEIN

# Activate GROMACS environment
source /apps/spack/share/spack/setup-env.sh
spack env activate gromacs

# Check that gmx_mpi exists
which gmx_mpi

# Prepare Inputs
grep -v -e HETATM -e CONECT ${PDB_FILE} >${PROTEIN}_protein.pdb

# Generate Topology
mpirun -n 1 gmx_mpi pdb2gmx -f ${PROTEIN}_protein.pdb -o ${PROTEIN}_processed.gro -water tip3p -ff "charmm27"

# Solvate System
mpirun -n 1 gmx_mpi editconf -f ${PROTEIN}_processed.gro -o ${PROTEIN}_newbox.gro -c -d 1.0 -bt dodecahedron
mpirun -n 1 gmx_mpi solvate -cp ${PROTEIN}_newbox.gro -cs spc216.gro -o ${PROTEIN}_solv.gro -p topol.top

# Add ions
mpirun -n 1 gmx_mpi grompp -maxwarn 1 -f config/ions.mdp -c ${PROTEIN}_solv.gro -p topol.top -o ions.tpr
printf "SOL\n" | mpirun -n 1 gmx_mpi genion -s ions.tpr -o ${PROTEIN}_solv_ions.gro -conc 0.15 -p topol.top -pname NA -nname CL -neutral

# Launch MPI jobs

MDRUN_GPU_PARAMS="-gputasks 00 -bonded gpu -nb gpu -pme gpu -update gpu"
MDRUN_MPIRUN_PREAMBLE="mpirun -n 1 -H localhost env GMX_ENABLE_DIRECT_GPU_COMM=1"

# Run energy minimization
mpirun -n 1 gmx_mpi grompp -maxwarn 1 -f config/emin-charmm.mdp -c ${PROTEIN}_solv_ions.gro -p topol.top -o em.tpr
$MDRUN_MPIRUN_PREAMBLE gmx_mpi mdrun -v -deffnm em

# Run temperature equilibration
mpirun -n 1 gmx_mpi grompp -maxwarn 1 -f config/nvt-charmm.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
$MDRUN_MPIRUN_PREAMBLE gmx_mpi mdrun -v -deffnm nvt "$MDRUN_GPU_PARAMS"

# Run pressure equilibration
mpirun -n 1 gmx_mpi grompp -maxwarn 1 -f config/npt-charmm.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
$MDRUN_MPIRUN_PREAMBLE gmx_mpi mdrun -v -deffnm npt "$MDRUN_GPU_PARAMS"

# Run production run
mpirun -n 1 gmx_mpi grompp -maxwarn 1 -f config/md-charmm.mdp -c npt.gro -t npt.cpt -p topol.top -o md.tpr
$MDRUN_MPIRUN_PREAMBLE gmx_mpi mdrun -v -deffnm md "$MDRUN_GPU_PARAMS"

# Post process trajectory
printf "1\n1\n" | mpirun -n 1 gmx_mpi trjconv -s md.tpr -f md.xtc -o md_center.xtc -center -pbc mol
