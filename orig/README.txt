# File: README.txt
#
#  Instructions for installing on-cluster MATLAB Support Package
#

Version: R2025a
Date: 2025-07-21

1. Description of files

  . Getting_Started_With_Serial_And_Parallel_MATLAB.docx : User Guide to be
       posted on internal wiki page.
  . explorer.Cluster.zip : MATLAB scripts for submitting on-prem Slurm jobs.
       To be installed on EXPLORER in the root MATLAB directory (e.g., /path/to/MATLAB)
  . Northeastern-University-NEU.Desktop.zip : MATLAB scripts for submitting remote Slurm
       jobs.  To be posted on internal wiki page.

NOTE: User Guide needs to be updated to reflect the location of
Northeastern-University-NEU.Desktop.zip (highlighted in yellow in the document.)


2. Installation

  unzip explorer.Cluster.zip -d /path/to/MATLAB


3. Update *each* MATLAB module file (e.g., /path/to/modules/MATLAB/R2025a)

LUA
===
  local SUPPORT_PACKAGES = "/path/to/MATLAB/support_packages"
  local MATLAB_CLUSTER_PROFILES_LOCATION = pathJoin(SUPPORT_PACKAGES,"matlab_parallel_server/scripts")
  setenv("MATLAB_CLUSTER_PROFILES_LOCATION", MATLAB_CLUSTER_PROFILES_LOCATION)

  append_path("PATH", pathJoin(SUPPORT_PACKAGES,"matlab_parallel_server/bin"))
  prepend_path("MATLABPATH", MATLAB_CLUSTER_PROFILES_LOCATION)

TCL
===
  set SUPPORT_PACKAGES                  /path/to/MATLAB/support_packages
  set MATLAB_CLUSTER_PROFILES_LOCATION  $SUPPORT_PACKAGES/matlab_parallel_server/scripts

  append-path   PATH                    $SUPPORT_PACKAGES/matlab_parallel_server/bin
  prepend-path  MATLABPATH              $MATLAB_CLUSTER_PROFILES_LOCATION
  prepend-path  MATLAB_CLUSTER_PROFILES_LOCATION $MATLAB_CLUSTER_PROFILES_LOCATION
