%FUNCTION TO GENERATE NODE PLACEMENTS RNG
%Function takes no input and returns a 1x2 array with the first index
%containing the R value (50-1600m) and the second index containing a phi
%value between 30 and 150 deg converted to rads.
function node = generateNode()
   r = 200 + (1400) * rand();  % R between 100 and 1600 meters
   phi = 0.5236 + (2.618-.5236) * rand();   % PHI between 30 and 150 degrees converted to rads
   node = [r, phi];
end

