# How To

1. Open a terminal and run:

~/add_env_modelsim.sh 
python3 run.py --gui

2. To load the waveforms, once inside ModelSim or Questa, go to Tools -> Execute Macro  and open the file wave_t2mi_to_t2_top.do

3. Finally in Modelsim or Questa, run the command vunit_restart

## Warning

The command python3 run.py --clear erases the vunit_out/ folder

In case it is necessary to recompile the RAM IP block, follow this tutorial:

https://vhdlwhiz.com/link-quartus-ip-libraries-to-vunit/


