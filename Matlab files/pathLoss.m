
%This function will use the friis transmission formula to estimate straight
%line path loss in air.  Takes node as input and returns loss as dB float.
function path_loss = pathLoss (node, pattern)
        path_loss = 1.8 + pattern(round(node(2) / 0.01745)) + 20*log10(.328/(4*pi*node(1)));
        %path_loss_lin = (0.328^2 * 1.8 * pattern(round(node(2) / 0.01745)))  / (4*pi*node(1))^2;
        %path_loss = 10*log10(path_loss_lin);
end