%% File: computePattern.m
function pattern = computePattern(basePattern, phaseShift)
    N = numel(basePattern);
    phi = linspace(0,2*pi,N);
    amplitude = ones(1,N);
    k = 2*pi/328; d = 175;
    af = zeros(size(phi));
    for idx = 1:N
        af(idx) = abs(sum(amplitude .* exp(1j*phaseShift) .* ...
                      exp(1j*(0:N-1)*k*d*cos(phi(idx)))));
    end
    af_dB = 10*log10(af + eps);
    pattern = basePattern + af_dB;
end