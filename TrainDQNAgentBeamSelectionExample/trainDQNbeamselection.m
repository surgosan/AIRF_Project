rng(0)

useSavedData = true;
if useSavedData
    % Load data generated from Neural Network for Beam Selection example
    load nnBS_TrainingData
    load nnBS_TestData
    load nnBS_position
else
    % Generate data
    helperNNBSGenerateData(); %#ok
    position.posTX = prm.posTx;
    position.ScatPos = prm.ScatPos;
end
locationMat = locationMatTrain(1:4:end,:);

% Sort location in clockwise order
secLen = size(locationMat,1)/4;
[~,b1] = sort(locationMat(1:secLen,2));
[~,b2] = sort(locationMat(secLen+1:2*secLen,1));
[~,b3] = sort(locationMat(2*secLen+1:3*secLen,2),"descend");
[~,b4] = sort(locationMat(3*secLen+1:4*secLen,1),"descend");
idx = [b1;secLen+b2;2*secLen+b3;3*secLen+b4];

locationMat =  locationMat(idx,:);

% Compute average RSRP for each gNB beam and sort in clockwise order
avgRsrpMatTrain = rsrpMatTrain/4;    % prm.NRepeatSameLoc=4;
avgRsrpMatTrain = 100*avgRsrpMatTrain./max(avgRsrpMatTrain, [],"all");
avgRsrpMatTrain = avgRsrpMatTrain(:,:,idx);
avgRsrpMatTrain = mean(avgRsrpMatTrain,1);

% Angle rotation matrix: update for nBeams>4
txBeamAng = [-78,7,92,177];
rotAngleMat = [
    0 85 170 105
    85 0 85 170
    170 85 0 85
    105 170 85 0];
rotAngleMat = 100*rotAngleMat./max(rotAngleMat,[],"all");

% Create training environment using generated data
envTrain = BeamSelectEnv(locationMat,avgRsrpMatTrain,rotAngleMat,position);
obsInfo = getObservationInfo(envTrain);
actInfo = getActionInfo(envTrain);
agent = rlDQNAgent(obsInfo,actInfo);
criticNetwork = getModel(getCritic(agent));
analyzeNetwork(criticNetwork)
agent.AgentOptions.CriticOptimizerOptions.LearnRate = 1e-3;
agent.AgentOptions.EpsilonGreedyExploration.EpsilonDecay = 1e-4;
trainOpts = rlTrainingOptions(...
    MaxEpisodes=500, ...
    MaxStepsPerEpisode=200, ...         % training data size = 200
    StopTrainingCriteria="AverageSteps", ...
    StopTrainingValue=500, ...
    Plots="training-progress"); 
doTraining = false;
if doTraining
    trainingStats = train(agent,envTrain,trainOpts);
else
    load("nnBS_RLAgent.mat")       
end
locationMat = locationMatTest(1:4:end,:);

% Sort location in clockwise order
secLen = size(locationMat,1)/4;
[~,b1] = sort(locationMat(1:secLen,2));  
[~,b2] = sort(locationMat(secLen+1:2*secLen,1));
[~,b3] = sort(locationMat(2*secLen+1:3*secLen,2),"descend");
[~,b4] = sort(locationMat(3*secLen+1:4*secLen,1),"descend");
idx = [b1;secLen+b2;2*secLen+b3;3*secLen+b4];

locationMat =  locationMat(idx,:);

% Compute average RSRP
avgRsrpMatTest = rsrpMatTest/4;  % 4 = prm.NRepeatSameLoc;
avgRsrpMatTest = 100*avgRsrpMatTest./max(avgRsrpMatTest, [],"all");
avgRsrpMatTest = avgRsrpMatTest(:,:,idx);
avgRsrpMatTest = mean(avgRsrpMatTest,1);

% Create test environment
envTest = BeamSelectEnv(locationMat,avgRsrpMatTest,rotAngleMat,position);
plot(envTest)
sim(envTest,agent,rlSimulationOptions("MaxSteps",100))
maxPosibleRsrp = sum(max(squeeze(avgRsrpMatTest)));
rsrpSim =  envTest.EpisodeRsrp;
disp("Agent RSRP/Maximum RSRP = " + rsrpSim/maxPosibleRsrp*100 +"%")

