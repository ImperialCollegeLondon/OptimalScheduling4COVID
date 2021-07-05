# ReadMe

This repository contains the source code, input data, installations instructions for the following models:

1. optimized-schedule: LP optimization model and data
2. cancellation-policy: model files and data for the cancellation policy (simulation code)

The scripts and methodology used for data treatment are available open-source at:
https://github.com/HFAnalyticsLab/overflow_analysis

# 1. Optimized Schedule

The optimized-schedule has been originally written in AMPL using the commercial solver CPLEX (which we recommend for efficiently solving this problem).
It is hereby made available open-source using GLPK (v5.0).

## Content of the folder

- opt-schedule.mod: LP model file
- opt-schedule.dat: data file
- output: output folder

## Installation/running instructions

1. Install GLPK/GLPSOL:

a) on Mac OS X (Option 1, recommended): use homebrew
http://arnab-deka.com/posts/2010/02/installing-glpk-on-a-mac/

b) on Mac Os X (Option 2)/Linux:
- Download the latest version of GLPK from: http://www.gnu.org/software/glpk/#downloading
- Install GLPK from the command line

$ cd ~/Downloads  
$ tar -xzf glpk-5.0.tar.gz  
$ cd  glpk-5.0 [or newer version]  
$ ./configure --prefix=/usr/local  
$ make  
$ sudo make install  

See if your system recognises it. Executing from the command line:

$ which glpsol

should reveal:

$ /usr/local/bin/glpsol

Now try:

$ glpsol --help

Source: http://hichenwang.blogspot.ch/2011/08/fw-installing-glpk-on-mac.html

c) on Windows:

- Download the source files from: https://sourceforge.net/projects/winglpk/files/latest/download
- Extract the files in a folder. Depending on your operating system use glpsol.exe from:
./w64 if running on a 64 bit version
./w32 if running on a 64 bit version
- For facilitating the access to glpsol.exe you can add the full path (depending on your operating system, see below) from the previous point to the system variables PATH
This guide could also be useful: http://www.osemosys.org/uploads/1/8/5/0/18504136/glpk_installation_guide_for_windows10_-_201702.pdf

2. Clone/download the content of this folder
3. Navigate to the folder 'optimized-schedule' folder via terminal/cmd prompt and execute (check glpsol documentation for more options):

$ glpsol --dual -m opt-schedule.mod -d opt-schedule.dat
(You might need to use 'glpsol.exe' instead of 'glpsol' on Windows)

4. All outputs will be available in the output folder.

If the command at point (3) did not run, it might be that glpsol is not on your PATH. Two solutions for that:
- (not recommended) instead of "glpsol" use the full path, e.g. on Mac '/usr/local/bin/glpsol -m opt-schedule.mod -d opt-schedule.dat'
- (recommended) add the folder in which glpsol is installed to the PATH. e.g. on Windows 7 (e.g., https://sourcedaddy.com/windows-7/changing-the-path.html). on mac (from terminal) 'export PATH=/usr/local/bin:$PATH' (if glpsol is installed in /usr/local/bin)

## Runtime

Installation takes a few minutes on a standard desktop computer.
The runtime is about 1-2 mins using CPLEX as solver.
The runtime can be significantly longer using GLPK/GLPSOL.

# 2. Cancellation Policy

The cancellation policy is a simulation code implemented in python.
The 24 Standard Policy scenarios reported in the paper can be run by following the detailed instructions contained in the file simulations_instructions.xlsx.

## Content of the folder

- canc_pol_sim.py: python simulation model
- input_data.xlsx: input data in Excel format
- simulations_instructions.xlsx: instructions to run the 24 Standard Policy scenarios
- output/G_output.xlsx: output folder containing an example output file

## Runtime

Installation takes a few minutes on a standard desktop computer.
Run time for scenario (G17) in the code: 198.27s