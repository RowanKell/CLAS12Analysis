#!/bin/bash
# --------------------------
# Hipo dir defintions
# --------------------------
RGA_F18_IN="/cache/clas12/rg-a/production/recon/fall2018/torus-1/pass1/v1/dst/train/nSidis/"
RGA_F18_OUT="/cache/clas12/rg-a/production/recon/fall2018/torus+1/pass1/v1/dst/train/nSidis/"
RGA_S19_IN="/cache/clas12/rg-a/production/recon/spring2019/torus-1/pass1/v1/dst/train/nSidis/"

# --------------------------
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# User edits fields below
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# --------------------------

# Location of CLAS12Analysis directory
# --------------------------------------------------------
CLAS12Analysisdir="/work/clas12/users/gmat/CLAS12Analysis/"

# Location of hipo directories for analysis
# --------------------------------------------------------
hipodirs=($RGA_F18_IN $RGA_F18_OUT $RGA_S19_IN)

# Beam energy associated with hipo files
# --------------------------------------------------------
beamEs=(10.6 10.6 10.2)

# Name of output directory
# --------------------------------------------------------
#outdir="/volatile/clas12/users/gmat/clas12analysis.sidis.data/fall2018-torus-1-v1-nSidis"
outdir="/volatile/clas12/users/gmat/clas12analysis.sidis.data/rg-a"

# Prefix for the output files from the analysis
# --------------------------------------------------------
rootname="july7"

# Process macro code location
# --------------------------------------------------------
processcodelocation="macros/dihadron_process/"
processcodename="pipi0_process.C"

# PostProcess macro code location
# --------------------------------------------------------
postprocesscodelocation="macros/dihadron_process/"
postprocesscodename="pipi0_postprocess_only.C"

# Location of clas12root package
# --------------------------------------------------------
clas12rootdir="/work/clas12/users/gmat/packages/clas12root"


# --------------------------
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# No more editing below
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# *-*-*-*-*-*-*-*-*-*-*-*-*-
# --------------------------

workdir=$CLAS12Analysisdir
outputdir=$outdir
outputdir+="/"
outputdir+=$rootname
processdir=$CLAS12Analysisdir
processdir+=$processcodelocation
shellSlurmDir="${outputdir}/shells"
outputSlurmDir="${outputdir}/output"
runJobs="${shellSlurmDir}/runJobs.sh"
runJobsPostProcess="${shellSlurmDir}/runJobsPostProcess.sh"
waitFile="${outputSlurmDir}/wait.sh"
waitJob="${outputSlurmDir}/waitJob.sh"
mergeJob="${outputSlurmDir}/mergeJob.sh"

if [ -d "$outputdir" ]; then rm -Rf $outputdir; fi
mkdir $outputdir
mkdir $shellSlurmDir
mkdir $outputSlurmDir

i=0
for h_idx in "${!hipodirs[@]}"
do
    hipodir=${hipodirs[$h_idx]}
    for hipofile in "$hipodir"/*
    do
	beamE=${beamEs[$h_idx]}
	processFile="${shellSlurmDir}/${rootname}_${i}.sh"
	touch $processFile
	chmod +x $processFile
	echo "#!/bin/tcsh" > $processFile
	echo "source /group/clas12/packages/setup.csh" >> $processFile
	echo "module load clas12/pro" >> $processFile
	echo "set CLAS12ROOT=${clas12rootdir}" >> $processFile
	echo "cd ${outputSlurmDir}" >> $processFile
       	echo "rm ${rootname}_${i}.out" >> $processFile
	echo "cd ${processdir}" >> $processFile    
	echo "clas12root ${processcodename}\\(\\\"${hipofile}\\\",\\\"${outputdir}/${rootname}_${i}.root\\\",${beamE}\\)" >> $processFile   

	postprocessFile="${shellSlurmDir}/${rootname}_${i}_postprocess.sh"
	touch $postprocessFile
	chmod +x $postprocessFile
	echo "#!/bin/tcsh" > $postprocessFile
	echo "source /group/clas12/packages/setup.csh" >> $postprocessFile
	echo "module load clas12/pro" >> $postprocessFile
	echo "set CLAS12ROOT=${clas12rootdir}" >> $postprocessFile
	echo "cd ${outputSlurmDir}" >> $postprocessFile
	echo "rm ${rootname}_${i}.out" >> $postprocessFile
	echo "cd ${postprocessdir}" >> $postprocessFile    
	echo "clas12root ${postprocesscodename}\\(\\\"${outputdir}/${rootname}_${i}.root\\\",${beamE}\\)" >> $postprocessFile   
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
echo "#SBATCH --mem-per-cpu=8000" >> $runJobs
echo "#SBATCH --job-name=${rootname}" >> $runJobs
echo "#SBATCH --cpus-per-task=4" >> $runJobs
echo "#SBATCH --time=24:00:00" >> $runJobs
echo "#SBATCH --chdir=${workdir}" >> $runJobs
echo "#SBATCH --array=0-${i}" >> $runJobs
echo "#SBATCH --output=${outputSlurmDir}/%x-%a.out" >> $runJobs
echo "#SBATCH --error=${outputSlurmDir}/%x-%a.err" >> $runJobs    
echo "${shellSlurmDir}/${rootname}_\${SLURM_ARRAY_TASK_ID}.sh" >> $runJobs


# Create script to run SIDISKinematicsReco postprocess on hipo files
# Unlike the script above, this postprocess exclusive script is meant to be
# run manually by the user in the case they want to make subtle changes
# to the post-processing module, without completely re-analyzing the HIPO files
# --------------------------------------------------------------------------
touch $runJobsPostProcess
chmod +x $runJobsPostProcess

echo "#!/bin/bash" > $runJobsPostProcess
echo "#SBATCH --account=clas12" >> $runJobsPostProcess
echo "#SBATCH --partition=production" >> $runJobsPostProcess
echo "#SBATCH --mem-per-cpu=4000" >> $runJobsPostProcess
echo "#SBATCH --job-name=${rootname}" >> $runJobsPostProcess
echo "#SBATCH --cpus-per-task=4" >> $runJobsPostProcess
echo "#SBATCH --time=24:00:00" >> $runJobsPostProcess
echo "#SBATCH --chdir=${workdir}" >> $runJobsPostProcess
echo "#SBATCH --array=0-${i}" >> $runJobsPostProcess
echo "#SBATCH --output=${outputSlurmDir}/%x-%a.out" >> $runJobsPostProcess
echo "#SBATCH --error=${outputSlurmDir}/%x-%a.err" >> $runJobsPostProcess    
echo "${shellSlurmDir}/${rootname}_\${SLURM_ARRAY_TASK_ID}_postprocess.sh" >> $runJobsPostProcess
echo "sbatch $waitJob" >> $runJobsPostProcess

# Create a file which will wait until (int) 0 is outputted by each job
# This signifies the end of the batch
# When all jobs are complete, this script will proceed to then...
#    - Queue merging of all tree_postprocess in the separate .root files
#    - ???
#    - ???
# --------------------------------------------------------------------
touch $waitFile
chmod +x $waitFile
echo "#!/bin/bash" > $waitFile
echo "cd $outputSlurmDir" >> $waitFile
echo "waitOutFile=\"wait.txt\"" >> $waitFile
echo "touch \$waitOutFile" >> $waitFile
echo "finishedJobs=0" >> $waitFile
echo "nJobs=$(($i+1))" >> $waitFile
echo "lastLine=\"\"" >> $waitFile
echo "while [ \$finishedJobs -ne \$nJobs ]" >> $waitFile
echo "do" >> $waitFile
echo "    finishedJobs=0" >> $waitFile
echo "    for outputFile in ./*.out" >> $waitFile
echo "    do" >> $waitFile
echo "        lastLine=\$(tail -1 \$outputFile)" >> $waitFile
echo "        if [[ \"\$lastLine\" == \"(int) 0\" ]]; then" >>  $waitFile
echo "            finishedJobs=\$((finishedJobs+1))" >> $waitFile
echo "        fi" >> $waitFile
echo "    done" >> $waitFile
echo "echo \"\$finishedJobs completed out of \$nJobs\" >> \$waitOutFile" >> $waitFile 
echo "sleep 30" >> $waitFile
echo "done" >> $waitFile
echo "sbatch ${mergeJob}" >> $waitFile

# Job for running the wait script
# ------------------------------------------------
touch $waitJob
chmod +x $waitJob
echo "#!/bin/bash" > $waitJob
echo "#SBATCH --account=clas12" >> $waitJob
echo "#SBATCH --partition=production" >> $waitJob
echo "#SBATCH --mem-per-cpu=2000" >> $waitJob
echo "#SBATCH --job-name=${rootname}_waitjob" >> $waitJob
echo "#SBATCH --cpus-per-task=1" >> $waitJob
echo "#SBATCH --time=24:00:00" >> $waitJob
echo "#SBATCH --chdir=${workdir}" >> $waitJob
echo "#SBATCH --output=${outputSlurmDir}/wait-%x-%a.out" >> $waitJob
echo "#SBATCH --error=${outputSlurmDir}/wait-%x-%a.err" >> $waitJob    
echo "${outputSlurmDir}/wait.sh" >> $waitJob


# Job for merging all the tree_postprocess' into one
# -----------------------------------------------------
touch $mergeJob
chmod +x $mergeJob

echo "#!/bin/bash" > $mergeJob
echo "#SBATCH --account=clas12" >> $mergeJob
echo "#SBATCH --partition=production" >> $mergeJob
echo "#SBATCH --mem-per-cpu=16000" >> $mergeJob
echo "#SBATCH --job-name=${rootname}_mergejob" >> $mergeJob
echo "#SBATCH --cpus-per-task=4" >> $mergeJob
echo "#SBATCH --time=24:00:00" >> $mergeJob
echo "#SBATCH --chdir=${workdir}" >> $mergeJob
echo "#SBATCH --output=${outputSlurmDir}/merge-%x-%a.out" >> $mergeJob
echo "#SBATCH --error=${outputSlurmDir}/merge-%x-%a.err" >> $mergeJob    
echo "clas12root ${workdir}/macros/mergeTrees.C\(\\\"${outputdir}/${rootname}*.root\\\",\\\"${outputdir}/merged_${rootname}.root\\\"\)" >> $mergeJob

echo "Submitting analysis jobs for the selected HIPO files"
echo " "
sbatch $runJobs
echo "----------------------------------------------------"
echo "Submitting wait script"
echo " "
sbatch $waitJob
echo "----------------------------------------------------"
