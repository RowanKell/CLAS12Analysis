#!/bin/bash
# --------------------------
# Hipo dir defintions
# --------------------------

RGC_SU22="/volatile/clas12/rg-c/production/ana_data/dst/train/sidisdvcs/"

# --------------------------
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# User edits fields below
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# --------------------------

# Username
# --------------------------------------------------------
username="gmat"

# Location of CLAS12Analysis directory
# --------------------------------------------------------
CLAS12Analysisdir="/work/clas12/users/gmat/CLAS12Analysis/"

# Location of hipo directories for analysis
# --------------------------------------------------------
declare -a hipodirs=($RGC_SU22)

# Beam energy associated with hipo files
# --------------------------------------------------------
beamEs=(10.5)

# Name of output directory
# --------------------------------------------------------
outdir="clas12analysis.sidis.data/rgc-su-train"

# Prefix for the output files from the analysis
# --------------------------------------------------------
rootname="aug23_elastic"

# Code locations
# --------------------------------------------------------
processcode="${CLAS12Analysisdir}/macros/process/rg-c/inclusive_RGC_process.C"
organizecode="${CLAS12Analysisdir}/macros/organize_rgc.py"

# Location of clas12root package
# --------------------------------------------------------
clas12rootdir="/work/clas12/users/gmat/packages/clas12root"

# Job Parameters
# --------------------------------------------------------
memPerCPU=4000
nCPUs=4

# --------------------------
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# No more editing below
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# --------------------------
farmoutdir="/farm_out/$username/$outdir/$rootname/"
volatiledir="/volatile/clas12/users/$username/$outdir"
outputdir="$volatiledir/$rootname"
workdir=$CLAS12Analysisdir
processdir="$CLAS12Analysisdir/$processcodelocation"

shellSlurmDir="${farmoutdir}/shells"
outputSlurmDir="${farmoutdir}/output"

runJobs="${shellSlurmDir}/runJobs.sh"
makeJobsPostProcess="${shellSlurmDir}/makeJobsPostProcess.sh"
runJobsPostProcess="${shellSlurmDir}/runJobsPostProcess.sh"
mergeFile="${shellSlurmDir}/merge.sh"
mergeSlurm="${shellSlurmDir}/mergeSlurm.slurm"

if [ -d "$farmoutdir" ]; then rm -Rf $farmoutdir; fi
if [ ! -d "$volatiledir" ]; then mkdir $volatiledir; fi
if [ -d "$outputdir" ]; then rm -Rf $outputdir; fi
mkdir $farmoutdir
mkdir $outputdir
mkdir $shellSlurmDir
mkdir $outputSlurmDir

i=0
for idx in "${!beamEs[@]}"
do
    beamE=${beamEs[$idx]}
    hipodir=${hipodirs[$idx]}
    for hipofile in "$hipodir"*
    do
	read runNumber <<< $(echo $hipofile | grep -oP '(?<=sidisdvcs_0).*(?=.hipo)')
	echo "Creating processing script for hipo file $((i+1))"
	processFile="${shellSlurmDir}/${rootname}_${i}.sh"
	touch $processFile
	chmod +x $processFile
	echo "#!/bin/tcsh" > $processFile
	echo "source /group/clas12/packages/setup.csh" >> $processFile
	echo "module load clas12/pro" >> $processFile
	echo "set CLAS12ROOT=${clas12rootdir}" >> $processFile
	echo "cd ${outputSlurmDir}" >> $processFile
	echo "clas12root ${processcode}\\(\\\"${hipofile}\\\",\\\"${outputdir}/${rootname}_${runNumber}.root\\\",${beamE}\\)" >> $processFile   
	postprocessFile="${shellSlurmDir}/${rootname}_${i}_postprocess.sh"
	touch $postprocessFile
	chmod +x $postprocessFile
	echo "#!/bin/tcsh" > $postprocessFile
	echo "source /group/clas12/packages/setup.csh" >> $postprocessFile
	echo "module load clas12/pro" >> $postprocessFile
	echo "set CLAS12ROOT=${clas12rootdir}" >> $postprocessFile
	echo "cd ${outputSlurmDir}" >> $postprocessFile
	echo "clas12root ${postprocesscode}\\(\\\"${outputdir}/${rootname}_${runNumber}.root\\\",${beamE}\\)" >> $postprocessFile   
	i=$((i+1))
    done
done

i=$((i-1))

# Create script to run SIDISKinematicsReco process+postprocess on hipo files
# --------------------------------------------------------------------------
touch $runJobs
chmod +x $runJobs
echo "#!/bin/bash" > $runJobs
echo "#SBATCH --account=clas12" >> $runJobs
echo "#SBATCH --partition=production" >> $runJobs
echo "#SBATCH --mem-per-cpu=${memPerCPU}" >> $runJobs
echo "#SBATCH --job-name=run${rootname}" >> $runJobs
echo "#SBATCH --cpus-per-task=${nCPUs}" >> $runJobs
echo "#SBATCH --time=24:00:00" >> $runJobs
echo "#SBATCH --chdir=${workdir}" >> $runJobs
echo "#SBATCH --array=0-${i}" >> $runJobs
echo "#SBATCH --output=${outputSlurmDir}/%x-%a.out" >> $runJobs
echo "#SBATCH --error=${outputSlurmDir}/%x-%a.err" >> $runJobs    
echo "${shellSlurmDir}/${rootname}_\${SLURM_ARRAY_TASK_ID}.sh" >> $runJobs

# Create a file which will wait until (int) 0 is outputted by each job
# This signifies the end of the batch
# Analysis chain flags can add Binning, Fitting, and Asymmetry calculations
# --------------------------------------------------------------------
touch $mergeFile
chmod +x $mergeFile

cat >> $mergeFile <<EOF
#!/bin/bash
cd \$outputSlurmDir
mergeOutFile=\"merge.txt\"
touch \$mergeOutFile
jobsLeft=999
while [ \$jobsLeft -ne 0 ]
do
    read jobsLeft <<< \$(echo "\$(squeue -u gmat --format="%.18i %.9P %.30j %.8u %.8T %.10M %.9l %.6D %R")" | grep run${rootname} | awk 'END{print NR}')
    echo \$jobsLeft >> \$mergeOutFile
sleep 30
done 
/apps/python/2.7.18/bin/python $organizecode $outputdir/ $rootname
EOF

# Job for running the merge script
# ------------------------------------------------
touch $mergeSlurm
chmod +x $mergeSlurm
echo "#!/bin/bash" > $mergeSlurm
echo "#SBATCH --account=clas12" >> $mergeSlurm
echo "#SBATCH --partition=production" >> $mergeSlurm
echo "#SBATCH --mem-per-cpu=${memPerCPU}" >> $mergeSlurm
echo "#SBATCH --job-name=mergejob_${rootname}" >> $mergeSlurm
echo "#SBATCH --cpus-per-task=${nCPUs}" >> $mergeSlurm
echo "#SBATCH --time=24:00:00" >> $mergeSlurm
echo "#SBATCH --chdir=${workdir}" >> $mergeSlurm
echo "#SBATCH --output=${outputSlurmDir}/merge.out" >> $mergeSlurm
echo "#SBATCH --error=${outputSlurmDir}/merge.err" >> $mergeSlurm    
echo "${mergeFile}" >> $mergeSlurm

echo "Submitting analysis jobs for the selected HIPO files"
echo " "
sbatch $runJobs
echo "----------------------------------------------------"
echo "Submitting merge script"
echo " "
sbatch $mergeSlurm
echo "----------------------------------------------------"
