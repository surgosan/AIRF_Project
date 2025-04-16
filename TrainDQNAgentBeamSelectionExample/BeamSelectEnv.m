classdef BeamSelectEnv < rl.env.MATLABEnvironment
    % BeamSelectEnv Beam Selection Environment
    %
    % A custom reinforcement learning environment created for Beam
    % Selection for a fixed number of transmit beams (=4)
    %
    % See also rlCreateEnvTemplate, TrainDQNAgentBeamSelectionExample.

    % Copyright 2022 The MathWorks, Inc.

    properties
        % Weights for reward
        RsrpWeight = 0.9
        AngleRotationWeight = 0.1

        % Episode rsrp
        EpisodeRsrp = 0
    end

    properties (Access = private)
        % 200x3 (NDiffLocTrain or NDiffLocTest x 3)
        LocationMat
        LocationMatScaled
        % 4x4x200 (row UE beam, column RX beam)
        RsrpMapping
        % Normalized rotation matrix, row for last action, col for new action
        RotAngleMat
        Pos
        
        % Figure handle
        Figure
        % Last action
        LastAction = 1
        % Current step count
        StepCount = 0
        % Current location index 0 < LocationIdx <= NumMaxLocation
        LocationIdx = 1
        BeamPlotLength = 5

        NumMaxLocation
    end

    properties (Constant)
        NumAction = 4
        TxBeamAng = [-78,7,92,177];
    end

    methods
        function this = BeamSelectEnv(locationMat,rsrpMapping,rotAngleMat,position)

            % Create action specifications
            actionInfo = rlFiniteSetSpec(1:4);
            % Create observation specifications
            observationInfo = [rlNumericSpec([1 2]) actionInfo];
            this = this@rl.env.MATLABEnvironment(observationInfo,actionInfo);

            % Normalize receiver locations
            this.LocationMatScaled = rescale(locationMat,0,1,"InputMax",[8 8 0],"InputMin",[2 2 0]);
            
            % Save data
            this.LocationMat = locationMat;
            this.RsrpMapping = rsrpMapping;
            this.RotAngleMat = rotAngleMat;
            this.Pos = position;
            this.NumMaxLocation = size(this.LocationMat,1);
        end

        function [observation,reward,isDone,loggedSignals] = step(this,action)
            % Simulate the environment with the given action for one step.

            if iscell(action)
                action = action{1};
            end

            % Compute rsrp for current action
            rsrpMap = this.RsrpMapping(:,:,this.LocationIdx);
            rsrp = rsrpMap(action);
            
            % is-done signal is always false, which means that there is no
            % early termination condition.
            isDone = false;

            % Compute reward
            % Angle rotation (not count if 1st step)
            angleRotation = 0;
            if this.StepCount > 0
                angleRotation = this.RotAngleMat(this.LastAction,action);
            end

            % Lose signal penalty
            reward = this.RsrpWeight*rsrp - angleRotation*this.AngleRotationWeight;

            % Compute next observation
            if this.LocationIdx < this.NumMaxLocation
                this.LocationIdx = this.LocationIdx + 1;
            else
                this.LocationIdx = 1;
            end
            nextLocation = getCoordinate(this.LocationMatScaled,this.LocationIdx);
            observation = {nextLocation action};
            this.LastAction = action;
            this.StepCount = this.StepCount + 1;

            loggedSignals.rsrp = rsrp;
            loggedSignals.RsrpReward = this.RsrpWeight*rsrp;
            loggedSignals.AnglePenalty = angleRotation*this.AngleRotationWeight;


            this.EpisodeRsrp = this.EpisodeRsrp + rsrp;
            % Use notifyEnvUpdated to signal that the
            % environment has been updated (e.g. to update visualization)
            notifyEnvUpdated(this);
        end

        function initialObservation = reset(this)
            % Reset the environment
            % This method is called at the beginning of each episode.

            % Select random starting receiver location
            this.LocationIdx = randi(this.NumMaxLocation);
            initialLocation = getCoordinate(this.LocationMatScaled,this.LocationIdx);
            initialAction = usample(this.ActionInfo);
            initialObservation = [{initialLocation} initialAction];
            this.LastAction = initialAction{1};
            this.StepCount = 0;

            this.EpisodeRsrp = 0;
            % Use notifyEnvUpdated to signal that the
            % environment has been updated (e.g. to update visualization)
            notifyEnvUpdated(this);
        end

        function plot(this)

            % Visualization
            this.Figure = figure;
            xlabel('x (m)')
            ylabel('y (m)')
            xlim([0 10])
            ylim([0 10])
            rectangle("Position",[2 2 6 6])
            coordinate = getCoordinate(this.LocationMat,this.LocationIdx);
            hold on
            scatter(this.Pos.posTX(1),this.Pos.posTX(2),'r^','filled');
            scatter(this.Pos.ScatPos(1,:),this.Pos.ScatPos(2,:),100,[0.929 0.694 0.125],'s','filled');
            angle = this.TxBeamAng(this.LastAction);
            x2=this.Pos.posTX(1)+(this.BeamPlotLength*cosd(angle));
            y2=this.Pos.posTX(2)+(this.BeamPlotLength*sind(angle));
            line([this.Pos.posTX(1) x2],[this.Pos.posTX(2) y2])
            hold off
            a = rectangle('Position',[coordinate(1:2) 0.2 0.2],'Curvature',[1 1],'FaceColor','green');

            envUpdatedCallback(this);
        end
    end

    methods (Access = protected)

        function envUpdatedCallback(this)
            % Update visualization everytime the environment is updated
            % (notifyEnvUpdated calls this)
               
            if ~isempty(this.Figure) && isvalid(this.Figure)
                ha = gca(this.Figure);
                coordinate = getCoordinate(this.LocationMat,this.LocationIdx);
                ha.Children(1).Position(1:2) = coordinate(1:2);

                angle = this.TxBeamAng(this.LastAction);
                x2=this.Pos.posTX(1)+(this.BeamPlotLength*cosd(angle));
                y2=this.Pos.posTX(2)+(this.BeamPlotLength*sind(angle));
                ha.Children(2).XData = [this.Pos.posTX(1) x2];
                ha.Children(2).YData = [this.Pos.posTX(2) y2];
                drawnow
            end
        end
    end
end

% Local function
function coordinate = getCoordinate(location,idx)
    coordinate = location(idx,1:2);
end