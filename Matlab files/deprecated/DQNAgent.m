%%Reward Function
%%selectedGainCoeff = amount of reward for increasing gain at the correct
%%node
%%nonSelectedGainCoeff = amount of penalty for gain at wrong nodes
%%powerCoeff = penalty for using extra power
reward = (selectedGainCoeff * selectedNode.gain()) - (sum(nonSelectedGainCoeff * otherNodes.gain()) + powerCoeff * totalPower)


% Create test environment
envTest = BeamSelectEnv(locationMat,avgRsrpMatTest,rotAngleMat,position);
plot(envTest)
sim(envTest,agent,rlSimulationOptions("MaxSteps",100))
maxPosibleRsrp = sum(max(squeeze(avgRsrpMatTest)));
rsrpSim =  envTest.EpisodeRsrp;
disp("Agent RSRP/Maximum RSRP = " + rsrpSim/maxPosibleRsrp*100 +"%")

