%% File: BeamformingEnv.m
classdef BeamformingEnv < rl.env.MATLABEnvironment
    properties
        ElementPattern    % Base element pattern (vector)
        Node              % [r, phi] from generateNode
        Losses            % [loss, r, phi1, phi2] rows
        Pt = 20;          % Transmit power (dBm)
    end
    properties(Access = protected)
        IsDone = false    % Episode termination flag
    end
    methods
        function this = BeamformingEnv(elementPattern)
            ObservationInfo = rlNumericSpec(size(elementPattern));
            ObservationInfo.Name = 'gainPattern';
            ActionInfo = rlFiniteSetSpec(0:10:360);
            ActionInfo.Name = 'phaseShift';
            this = this@rl.env.MATLABEnvironment(ObservationInfo, ActionInfo);
            this.ElementPattern = elementPattern;
            reset(this);
        end

        function [Observation, Reward, IsDone, LoggedSignals] = step(this, Action)
            currentPattern = computePattern(this.ElementPattern, Action);
            rTarget = pathLoss(this.Node, currentPattern);
            lossPenalty = 0;
            for k = 1:size(this.Losses,1)
                lossPenalty = lossPenalty + ...
                              isCollision(this.Node, this.Losses(k,:));
            end

            rTotal = rTarget + lossPenalty + this.Pt;
            powerUse = Action/360;
            Reward = rTotal - 0.1*powerUse;
            Observation = currentPattern;
            IsDone = true;
            LoggedSignals = [];
        end

        function InitialObservation = reset(this)
            this.Node   = generateNode();
            this.Losses = [generateLoss(); generateLoss()];
            InitialObservation = this.ElementPattern;
            this.IsDone = false;
        end
    end
end