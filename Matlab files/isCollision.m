
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