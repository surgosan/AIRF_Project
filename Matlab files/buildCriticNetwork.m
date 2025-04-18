%% File: buildCriticNetwork.m

function critic = buildCriticNetwork(obsInfo, actInfo)
    % buildCriticNetwork   Construct a Q-value network for continuous actions
    %
    %   critic = buildCriticNetwork(obsInfo, actInfo) returns an
    %   rlQValueRepresentation that takes as input the environment's
    %   observation and action, and outputs a scalar Q-value.

    % Flatten observation dimension
    obsDim = prod(obsInfo.Dimension);   % e.g. 360
    actDim = prod(actInfo.Dimension);   % 2

    % Observation (state) input path
    statePath = [
        featureInputLayer(obsDim, Name="state")
        fullyConnectedLayer(64, Name="s_fc1")
        reluLayer(           Name="s_relu1")
        fullyConnectedLayer(32, Name="s_fc2")
        ];

    % Action input path
    actionPath = [
        featureInputLayer(actDim, Name="action")
        fullyConnectedLayer(32, Name="a_fc1")
        ];

    % Common path to Q‑value output
    commonPath = [
        additionLayer(2, Name="add")
        reluLayer(    Name="common_relu")
        fullyConnectedLayer(1, Name="qOut")
        ];

    % Assemble the layers into a graph
    lgraph = layerGraph(statePath);
    lgraph = addLayers(lgraph, actionPath);
    lgraph = addLayers(lgraph, commonPath);

    % Connect the state and action paths into the addition layer
    lgraph = connectLayers(lgraph, "s_fc2", "add/in1");
    lgraph = connectLayers(lgraph, "a_fc1", "add/in2");

    % Create the rlQValueRepresentation
    critic = rlQValueRepresentation( ...
        lgraph, obsInfo, actInfo, ...
        ObservationInputNames="state", ...
        ActionInputNames     ="action" ...
    );
end
