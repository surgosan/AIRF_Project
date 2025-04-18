%% File: trainBeamformingAgent.m

if ~isfile("AAAMain.mat")
    AAAMain;
    save("AAAMain.mat","element")
else
    load("AAAMain.mat","element")
end

env = BeamformingEnv(element);
obsInfo = getObservationInfo(env);
actInfo = getActionInfo(env);

critic = buildCriticNetwork(obsInfo, actInfo);

actorNetwork = [
    featureInputLayer(prod(obsInfo.Dimension),Name="state")
    fullyConnectedLayer(64,Name="fc1")
    reluLayer(Name="relu1")
    fullyConnectedLayer(64,Name="fc2")
    reluLayer(Name="relu2")
    fullyConnectedLayer(prod(actInfo.Dimension),Name="action")
    tanhLayer(Name="tanh1")
    scalingLayer(Scale=[360;0.45], Bias=[0;0.55], Name="scale")  
    ];

actor = rlDeterministicActorRepresentation(actorNetwork, ...
    obsInfo, actInfo, ObservationInputNames="state", ActionOutputNames="action");

agentOpts = rlDDPGAgentOptions(...
    SampleTime=1, ...
    DiscountFactor=0.99, ...
    MiniBatchSize=64);

agent = rlDDPGAgent(actor, critic, agentOpts);
trainOpts = rlTrainingOptions(...
    MaxEpisodes=250, ...
    MaxStepsPerEpisode=1, ...
    ScoreAveragingWindowLength=20, ...
    Plots="training-progress", ...
    Verbose=false);

trainingStats = train(agent, env, trainOpts);
save("BeamformingAgent.mat","agent");
