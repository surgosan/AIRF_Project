%FunctionFile


%FUNCTION TO GENERATE NODE PLACEMENTS RNG
%Function takes no input and returns a 1x2 array with the first index
%containing the R value (50-1600m) and the second index containing a phi
%value between 30 and 150 deg converted to rads.
function node = generateNode()
   r = 200 + (1400) * rand();  % R between 100 and 1600 meters
   phi = 0.5236 + (2.618-.5236) * rand();   % PHI between 30 and 150 degrees converted to rads
   node = [r, phi];
end



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



%Function takes node and loss source as input.
%Determines if loss arc is on straight line path froom origin to node
%If yes return loss value
%if no return 0
function misc_loss = isCollision (node, loss_arc)
    if (node(1) > loss_arc(2)&& ...  % Node is behind arc
        node(2) >= loss_arc(3)&& ...  % Node is between the max and min phi
        node(2) <= loss_arc(4)) 
        misc_loss = loss_arc(1); %Then return loss
    else
        misc_loss=0; %Else no misc loss
    end
end


%This function will use the friis transmission formula to estimate straight
%line path loss in air.  Takes node as input and returns loss as dB float.
function path_loss = pathLoss (node, pattern)
        path_loss = 1.8 + pattern(round(node(2) / 0.01745)) + 20*log10(.328/(4*pi*node(1)));
        %path_loss_lin = (0.328^2 * 1.8 * pattern(round(node(2) / 0.01745)))  / (4*pi*node(1))^2;
        %path_loss = 10*log10(path_loss_lin);
end



pattern ()

arc1 = generateLoss()

node1 = generateNode()

misc_loss = isCollision(node1, arc1)

path_loss = pathLoss(node1, final_pattern)