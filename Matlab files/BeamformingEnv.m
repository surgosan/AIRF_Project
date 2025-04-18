%% File: BeamformingEnv.m

classdef BeamformingEnv < rl.env.MATLABEnvironment
    properties
        ElementPattern    % Base element pattern (vector)
        Node              % [r, phi] from generateNode()
        Losses            % N×4 array of loss arcs [loss, r, phi1, phi2]
        Pt = 20;          % Transmit power (dBm)
    end
    properties(Access = protected)
        IsDone = false    % Episode termination flag
    end
    methods
        function this = BeamformingEnv(elementPattern)
            obsInfo = rlNumericSpec(size(elementPattern));
            obsInfo.Name = 'gainPattern';

            actInfo = rlNumericSpec([2 1]);
            actInfo.Name = 'beamControl';
            actInfo.Description = {'phaseShift','ampScale'};
            actInfo.LowerLimit = [0; 0.1];
            actInfo.UpperLimit = [360; 1.0];
            this = this@rl.env.MATLABEnvironment(obsInfo, actInfo);

            this.ElementPattern = elementPattern;

            reset(this);
        end

        function [Observation, Reward, IsDone, LoggedSignals] = step(this, Action)
            phase    = Action(1);
            ampScale = Action(2);

            steered = computePattern(this.ElementPattern, phase);

            currentPattern = ampScale .* steered;

            rTarget = pathLoss(this.Node, currentPattern);

            lossPenalty = 0;
            for k = 1:size(this.Losses,1)
                lossPenalty = lossPenalty + ...
                              isCollision(this.Node, this.Losses(k,:));
            end

            rTotal = rTarget + lossPenalty + this.Pt;
            Reward = rTotal - 0.1 * ampScale;
            Observation   = currentPattern;
            IsDone        = true;
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
