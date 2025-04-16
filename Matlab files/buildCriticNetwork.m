%% File: buildCriticNetwork.m
function criticNetwork = buildCriticNetwork(obsInfo, actInfo)
    numActions = numel(actInfo.Elements);
    layers = [
        featureInputLayer(prod(obsInfo.Dimension),'Normalization','none','Name','state')
        fullyConnectedLayer(128,'Name','fc1')
        reluLayer('Name','relu1')
        fullyConnectedLayer(64,'Name','fc2')
        reluLayer('Name','relu2')
        fullyConnectedLayer(numActions,'Name','qOut')
    ];
    criticNetwork = layerGraph(layers);
end