function [optBeamPairIdxMatTrain,rsrpMatTrain] = ...
    hGenDataMIMOScatterChan(mode,locationMat,prm,txBurst,arrayTx,arrayRx,seed)
% hGenDataMIMOScatterChan Generate data for neural network based beam
% selection example
%
% See also NeuralNetworkBeamSelectionExample, NewRadioSSBBeamSweepingExample.

%   Copyright 2022 The MathWorks, Inc.

disp(['Generating ' mode ' data...'])

rng(seed);                     % Set RNG state for repeatability
c = physconst('LightSpeed');   % Propagation speed

if strcmp(mode, 'training')
   cnt = prm.NDiffLocTrain;
else % test
   cnt = prm.NDiffLocTest;
end

%% Burst Generation

% Configure an nrDLCarrierConfig object to use the synchronization signal
% burst parameters and to disable other channels. This object will be used
% by nrWaveformGenerator to generate the SS burst waveform.
cfgDL = configureWaveformGenerator(prm,txBurst);

% Get OFDM information
ofdmInfo = nrOFDMInfo(cfgDL.SCSCarriers{1}.NSizeGrid,prm.SCS);
sampleRate = ofdmInfo.SampleRate;

% Generate burst waveform
burstWaveform = nrWaveformGenerator(cfgDL);

%% Transmit-End Beam Sweeping
% Transmit beam angles in azimuth and elevation, equi-spaced
azBW = beamwidth(arrayTx,prm.CenterFreq,'Cut','Azimuth');
elBW = beamwidth(arrayTx,prm.CenterFreq,'Cut','Elevation');
txBeamAng = hGetBeamSweepAngles(prm.numBeams,prm.TxAZlim,prm.TxELlim, ...
    azBW,elBW,prm.ElevationSweep);

% For evaluating transmit-side steering weights
SteerVecTx = phased.SteeringVector('SensorArray',arrayTx, ...
    'PropagationSpeed',c);

% Get the set of OFDM symbols occupied by each SSB
numBlocks = length(txBurst.TransmittedBlocks);
burstStartSymbols = ssBurstStartSymbols(txBurst.BlockPattern,numBlocks);
burstStartSymbols = burstStartSymbols(txBurst.TransmittedBlocks==1);
burstOccupiedSymbols = burstStartSymbols.' + (1:4);

% Apply steering per OFDM symbol for each SSB
gridSymLengths = repmat(ofdmInfo.SymbolLengths,1,cfgDL.NumSubframes);
%   repeat burst over numTx to prepare for steering
strTxWaveform = repmat(burstWaveform,1,prm.NumTx)./sqrt(prm.NumTx);
for ssb = 1:prm.numBeams

    % Extract SSB waveform from burst
    blockSymbols = burstOccupiedSymbols(ssb,:);
    startSSBInd = sum(gridSymLengths(1:blockSymbols(1)-1))+1;
    endSSBInd = sum(gridSymLengths(1:blockSymbols(4)));
    ssbWaveform = strTxWaveform(startSSBInd:endSSBInd,1);

    % Generate weights for steered direction
    wT = SteerVecTx(prm.CenterFreq,txBeamAng(:,ssb));

    % Apply weights per transmit element to SSB
    strTxWaveform(startSSBInd:endSSBInd,:) = ssbWaveform.*(wT');

end

%% Receive-End Beam Sweeping and Measurement
% Receive beam angles in azimuth and elevation, equi-spaced
azBW = beamwidth(arrayRx,prm.CenterFreq,'Cut','Azimuth');
elBW = beamwidth(arrayRx,prm.CenterFreq,'Cut','Elevation');
rxBeamAng = hGetBeamSweepAngles(prm.numBeams,prm.RxAZlim,prm.RxELlim, ...
    azBW,elBW,prm.ElevationSweep);

% For evaluating receive-side steering weights
SteerVecRx = phased.SteeringVector('SensorArray',arrayRx, ...
    'PropagationSpeed',c);

% AWGN level
SNR = 10^(prm.SNRdB/20);                        % Convert to linear gain
N0 = 1/(sqrt(2.0*prm.NumRx*double(ofdmInfo.Nfft))*SNR); % Noise Std. Dev.

% Generate a reference grid for timing correction
%   assumes an SSB in first slot
carrier = nrCarrierConfig('NCellID',prm.NCellID);
carrier.NSizeGrid = cfgDL.SCSCarriers{1}.NSizeGrid;
carrier.SubcarrierSpacing = prm.SCS;
pssRef = nrPSS(carrier.NCellID);
pssInd = nrPSSIndices;
ibar_SSB = 0;
pbchdmrsRef = nrPBCHDMRS(carrier.NCellID,ibar_SSB);
pbchDMRSInd = nrPBCHDMRSIndices(carrier.NCellID);
pssGrid = zeros([240 4]);
pssGrid(pssInd) = pssRef;
pssGrid(pbchDMRSInd) = pbchdmrsRef;
refGrid = zeros([12*carrier.NSizeGrid ofdmInfo.SymbolsPerSlot]);
burstOccupiedSubcarriers = carrier.NSizeGrid*6 + (-119:120).';
refGrid(burstOccupiedSubcarriers, ...
    burstOccupiedSymbols(1,:)) = pssGrid;

%% Processing loop for each location

numReps = prm.NRepeatSameLoc;
rsrpMat = zeros(prm.numBeams,prm.numBeams,cnt);
% Each row represent a (numBeams*numBeams)-dim sample's output (containing
% a single "1" at the optimal beam pair index)
optBeamPairIdxMat = zeros(numReps,cnt,prm.numBeams*prm.numBeams); 

fprintf('  Total iterations: %d\n', cnt*numReps)
% Uncomment line below to use Parallel Computing Toolbox instead
%parfor locIdx = 1:cnt
for locIdx = 1:cnt
    posRx = locationMat((locIdx-1)*numReps+1, :)';   % Update rx position
    toRxRange = rangeangle(prm.posTx,posRx);
    spLoss = fspl(toRxRange,prm.lambda);    % Free space path loss

    % Configure channel
    % one per location, repeated for numReps use
    channel = phased.ScatteringMIMOChannel;
    channel.PropagationSpeed = c;
    channel.CarrierFrequency = prm.CenterFreq;
    channel.SampleRate = sampleRate;
    if posRx(2) >= prm.posTx(2)
        channel.SimulateDirectPath = true;
    else
        channel.SimulateDirectPath = false;
    end
    channel.ChannelResponseOutputPort = true;
    channel.Polarization = 'None';
    channel.TransmitArray = arrayTx;
    channel.TransmitArrayPosition = prm.posTx;
    channel.ReceiveArray = arrayRx;
    channel.ReceiveArrayPosition = posRx;
    channel.ScattererSpecificationSource = 'Property';
    channel.ScattererPosition = prm.ScatPos;
    channel.ScattererCoefficient = ones(1,size(prm.ScatPos,2));

    % Get maximum channel delay
    [~,~,tau] = channel(complex(randn(sampleRate*1e-3,prm.NumTx), ...
        randn(sampleRate*1e-3,prm.NumTx)));
    maxChDelay = ceil(max(tau)*sampleRate);

    % Receive gain in linear terms, to compensate for the path loss
    rxGain = 10^(spLoss/20);   

    for repeatIdx = 1:numReps

        idx = (locIdx-1)*numReps + repeatIdx;
        if mod(idx, 10) == 0
            disp(['  Iteration count = ' num2str(idx)]);
        end

        % Loop over all receive beams
        rsrp = zeros(prm.numBeams,prm.numBeams);
        for rIdx = 1:prm.numBeams

            % Fading channel, with path loss
            txWave = [strTxWaveform; zeros(maxChDelay,size(strTxWaveform,2))];
            fadWave = channel(txWave);

            % Receive gain, to compensate for the path loss
            fadWaveG = fadWave*rxGain;

            % Add WGN
            noise = N0*complex(randn(size(fadWaveG)),randn(size(fadWaveG)));
            rxWaveform = fadWaveG + noise;

            % Generate weights for steered direction
            wR = SteerVecRx(prm.CenterFreq,rxBeamAng(:,rIdx));

            % Apply weights per receive element
            if strcmp(prm.FreqRange, 'FR1')
                strRxWaveform = rxWaveform.*(wR');
            else  % for FR2, combine signal from antenna elements
                strRxWaveform = rxWaveform*conj(wR);
            end

            % Correct timing
            offset = nrTimingEstimate(carrier, ...
                strRxWaveform(1:sampleRate*1e-3,:),refGrid*wR(1)');
            if offset > maxChDelay
                offset = 0;
            end
            strRxWaveformS = strRxWaveform(1+offset:end,:);

            % OFDM Demodulate
            rxGrid = nrOFDMDemodulate(carrier,strRxWaveformS);

            % Loop over all SSBs in rxGrid (transmit end)
            for tIdx = 1:prm.numBeams
                % Get each SSB grid
                rxSSBGrid = rxGrid(burstOccupiedSubcarriers, ...
                    burstOccupiedSymbols(tIdx,:),:);

                % Make measurements, store per receive, transmit beam    
                measuredRsrp = measureSSB(rxSSBGrid,prm.RSRPMode,prm.NCellID);
                rsrp(rIdx,tIdx) = measuredRsrp;
            end
        end
        rsrpMat(:,:,locIdx) = rsrpMat(:,:,locIdx) + rsrp;

        %% Beam Determination
        [~,i] = max(rsrp,[],'all','linear');    % First occurrence is output
        % i is column-down first (for receive), then across columns (for transmit)
        [rxBeamID,txBeamID] = ind2sub([prm.numBeams prm.numBeams],i(1));
        optBeamIdx = (txBeamID-1)*prm.numBeams+rxBeamID;
        optBeamVec = zeros(prm.numBeams*prm.numBeams, 1);
        optBeamVec(optBeamIdx) = 1.0;
        optBeamPairIdxMat(repeatIdx,locIdx,:) = optBeamVec;                             

    end
end
optBeamPairIdxMatTrain = reshape(optBeamPairIdxMat,[],prm.numBeams*prm.numBeams);
rsrpMatTrain = rsrpMat;
disp(['Finished generating ' mode ' data.'])

% Check if there are two beams that are exactly the same
% rxSteerVecCollection = zeros(4,1, prm.numBeams); 
% for b = 1:prm.numBeams
%     rxSteerVecCollection(:,:,b) = SteerVecRx(prm.CenterFreq,rxBeamAng(:,b));
% end
% 
% txSteerVecCollection = zeros(64,1, prm.numBeams); 
% for b = 1:prm.numBeams
%     txSteerVecCollection(:,:,b) = SteerVecTx(prm.CenterFreq,txBeamAng(:,b));
% end
end

%% Local Functions
function cfgDL = configureWaveformGenerator(prm,txBurst)
% Configure an nrDLCarrierConfig object to be used by nrWaveformGenerator
% to generate the SS burst waveform.

    cfgDL = nrDLCarrierConfig;
    cfgDL.SCSCarriers{1}.SubcarrierSpacing = prm.SCS;
    if (prm.SCS==240)
        cfgDL.SCSCarriers = [cfgDL.SCSCarriers cfgDL.SCSCarriers];
        cfgDL.SCSCarriers{2}.SubcarrierSpacing = prm.SubcarrierSpacingCommon;
        cfgDL.BandwidthParts{1}.SubcarrierSpacing = prm.SubcarrierSpacingCommon;
    else
        cfgDL.BandwidthParts{1}.SubcarrierSpacing = prm.SCS;
    end
    cfgDL.PDSCH{1}.Enable = false;
    cfgDL.PDCCH{1}.Enable = false;
    cfgDL.ChannelBandwidth = prm.ChannelBandwidth;
    cfgDL.FrequencyRange = prm.FreqRange;
    cfgDL.NCellID = prm.NCellID;
    cfgDL.NumSubframes = 5;
    cfgDL.WindowingPercent = 0;
    cfgDL.SSBurst = txBurst;

end

function ssbStartSymbols = ssBurstStartSymbols(ssbBlockPattern,Lmax)
% Starting OFDM symbols of SS burst.

    % 'alln' gives the overall set of SS block indices 'n' described in 
    % TS 38.213 Section 4.1, from which a subset is used for each Case A-E
    alln = [0; 1; 2; 3; 5; 6; 7; 8; 10; 11; 12; 13; 15; 16; 17; 18];
    
    cases = {'Case A' 'Case B' 'Case C' 'Case D' 'Case E'};
    m = [14 28 14 28 56];
    i = {[2 8] [4 8 16 20] [2 8] [4 8 16 20] [8 12 16 20 32 36 40 44]};
    nn = [2 1 2 16 8];
    
    caseIdx = find(strcmpi(ssbBlockPattern,cases));
    if (any(caseIdx==[1 2 3]))
        if (Lmax==4)
            nn = nn(caseIdx);
        elseif (Lmax==8)
            nn = nn(caseIdx) * 2;
        end
    else
        if (Lmax==64)
            nn = nn(caseIdx);
        end
    end
    
    n = alln(1:nn);
    ssbStartSymbols = (i{caseIdx} + m(caseIdx)*n).';
    ssbStartSymbols = ssbStartSymbols(:).';
    
end

function rsrp = measureSSB(rxSSBGrid,mode,NCellID)
% Compute the reference signal received power (RSRP) based on SSS, and if
% selected, also PBCH DM-RS.

    sssInd = nrSSSIndices;                       % SSS indices

    numRx = size(rxSSBGrid,3);
    rsrpSSS = zeros(numRx,1);
    for rxIdx = 1:numRx
        % Extract signals per rx element
        rxSSBGridperRx = rxSSBGrid(:,:,rxIdx);
        rxSSS = rxSSBGridperRx(sssInd);

        % Average power contributions over all REs for RS
        rsrpSSS(rxIdx) = mean(rxSSS.*conj(rxSSS));
    end

    if strcmpi(mode,'SSSwDMRS')
        pbchDMRSIndLocal = nrPBCHDMRSIndices(NCellID);    % PBCH DM-RS indices
        rsrpDMRS = zeros(numRx,1);
        for rxIdx = 1:numRx
            % Extract signals per rx element
            rxSSBGridperRx = rxSSBGrid(:,:,rxIdx);
            rxPBCHDMRS = rxSSBGridperRx(pbchDMRSIndLocal);

            % Average power contributions over all REs for RS
            rsrpDMRS(rxIdx) = mean(rxPBCHDMRS.*conj(rxPBCHDMRS));
        end        
    end
    
    switch lower(mode)
        case 'sssonly'  % Only SSS
           rsrp = max(rsrpSSS);     % max over receive elements
        case 'ssswdmrs' % Both SSS and PBCH-DMRS, accounting for REs per RS
           rsrp = max((rsrpSSS*127+rsrpDMRS*144)/271); % max over receive elements
    end    
end
