function [InitialObservation, Info] = myReset()

    node1 = generateNode();
    node2 = generateNode();
    node3 = generateNode();
    node4 = generateNode();
    node5 = generateNode();

InitialObservation = [node1(1), node2(1), node3(1), node4(1), node5(1), ...
                      node1(2), node2(2), node3(2), node4(2), node5(2)]';

    % Save everything you’ll need later
    Info.NodePositions = [node1; node2; node3; node4; node5];  % 5x2 matrix [R, φ]
    %% --- Initialize Loss Values ---
    loss1 = generateLoss();
    loss2 = generateLoss();
    Info.loss1 = loss1;
    Info.loss2 = loss2;
    Info.StepCount = 0;  
end