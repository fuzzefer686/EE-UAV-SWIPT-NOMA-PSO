function [updatedPosition,convergence_curve] = positionUpdate_FA(xUAV, yUAV, zUAV, minRate, noUsers, xUser, yUser, g)
    %% init param
    alpha=0.2;
    Beta0=1;
    % gamma=1;
    
    num_partical=30;
    max_iteration=50;
    %% space constraint
    dx_min = max(-500, 0 - xUAV);
    dx_max = min(500, 2000 - xUAV);
    dx_length = abs(dx_max-dx_min);
    % Ràng buộc trục Z: Độ cao bắt buộc nằm trong [100, 300] 
    dz_min = 100 - zUAV;
    dz_max = 300 - zUAV;
    dz_length = abs(dz_max-dz_min);
    gamma = 1 / (dx_length^2 + dz_length^2);


    scale = [dx_length,dz_length];
    convergence_curve = zeros(1, max_iteration);
    %% init particals
    partical_position = zeros(num_partical,2); 

    partical_brightness = -inf * ones(num_partical,1);
    best_position = [0,0];
    best_value = -inf;
     %% randomly init the firefly
    for i=1:num_partical
        partical_position(i,1) = dx_min + rand() * dx_length;
        partical_position(i,2) = dz_min + rand() * dz_length;
       
    end
    %% FA main loop
    current_iteration = 1;
    while current_iteration<max_iteration 
    for i=1:num_partical 
        %obj func for all particals
        vars = partical_position(i, :);
        [minZ, ~] = objective_function_positionUpdate_3D(vars, xUAV, yUAV, zUAV, noUsers, xUser, yUser, minRate, g);
        fitness = minZ;
        
        partical_brightness(i)=fitness;
        if (fitness>best_value)
            best_position=partical_position(i,:);
            best_value = fitness;
        end
    end
    convergence_curve(current_iteration) = best_value;
    for i=1:num_partical
        for j=1:num_partical
            if i ~= j
                % if j is brighter than i
                if partical_brightness(j) > partical_brightness(i)
                    xi=partical_position(i,1);
                    zi=partical_position(i,2);
                    xj=partical_position(j,1);
                    zj=partical_position(j,2);
                    % distance i to j
                    r_ij=sqrt((xi-xj)*(xi-xj)+(zi-zj)*(zi-zj));
                    % attractiveness
                    Beta = Beta0 * exp((0-gamma)*r_ij*r_ij);
                    % movement 
                    partical_position(i,:)=partical_position(i,:) + ...
                                            Beta*(partical_position(j,:)-partical_position(i,:))+...
                                            alpha*(rand(1,2)-0.5).*scale;
                    % check out of range
                    partical_position(i, 1) = min(max(partical_position(i, 1), dx_min), dx_max);
                    partical_position(i, 2) = min(max(partical_position(i, 2), dz_min), dz_max);
             
                end
            end
        end
    end

    current_iteration=current_iteration+1;
    end
    % the brightest particles wouldnt move because theres nothing brighter than it
updatedPosition.position = best_position;
updatedPosition.minRate = best_value;
end