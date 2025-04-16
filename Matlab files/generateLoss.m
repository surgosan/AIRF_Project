
%Function to generate source of loss
%For simplicity just generate an arc that will be used to calculate a "ray
%traced" collision. Bounded between 100-1000 R value, 
% Arc length min is 5deg max is 30deg (Values returned in radians)
% Loss value between 5-20dB
function loss_arc = generateLoss()
     loss = rand() * 15 + 5                  %Generate a loss value of 5-20dB
     r = 25 + (675) * rand();               % R value between 25 and 700
     phi1 = 0.5236 + (1.92-.5236) * rand();% PHI start between 30 and 110 degrees converted to rads
     phi2 = phi1 + rand()* 0.349 + 0.1745 ;% Phi2 is Phi1 + between 10 and 40deg
     loss_arc = [loss, r, phi1, phi2];
end
