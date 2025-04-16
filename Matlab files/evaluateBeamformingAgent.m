%% File: evaluateBeamformingAgent.m
% Script to evaluate the trained DQN agent without invoking AAAMain plotting code

load('BeamformingAgent.mat','agent');

% Load only the saved element pattern
data = load('AAAMain.mat','element');
pattern = data.element;

env = BeamformingEnv(pattern);
simOpts = rlSimulationOptions('MaxSteps',1);
exp = sim(env,agent,simOpts);
disp('Evaluation complete.');
