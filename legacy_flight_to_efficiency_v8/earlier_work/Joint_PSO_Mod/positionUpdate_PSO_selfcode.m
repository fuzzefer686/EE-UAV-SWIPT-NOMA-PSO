function [updatedPosition,convergence_curve] = positionUpdate_PSO_selfcode(xUAV, yUAV, zUAV, minRate, noUsers, xUser, yUser, g)
    %% init param
    w_max = 0.9;
    w_min = 0.7;
    w=0.7;
    c1 = 2;
    c2 = 2;
    num_partical=30;
    max_iteration=50;
    %% space constraint
    dx_min = max(-500, 0 - xUAV);
    dx_max = min(500, 2000 - xUAV);
    dx_length = abs(dx_max-dx_min)
    % Ràng buộc trục Z: Độ cao bắt buộc nằm trong [100, 300] 
    dz_min = 100 - zUAV;
    dz_max = 300 - zUAV;
    dz_length = abs(dz_max-dz_min);
    convergence_curve = zeros(1, max_iteration);
    %% init particals
    partical_position = zeros(num_partical,2); %(0,1)
    partical_velocity = zeros(num_partical,2);
    
    pbest_position = zeros(num_partical,2);
    pbest_value = -inf * ones(num_partical,1); 

    gbest_position = [0,0];
    gbest_value = -inf;

    for i=1:num_partical
        partical_position(i,1) = dx_min + rand() * dx_length;
        partical_position(i,2) = dz_min + rand() * dz_length;
        partical_velocity(i,:) = [0,0];

        vars = partical_position(i,:);
        [minZ, ~] = objective_function_positionUpdate_3D(vars, xUAV, yUAV, zUAV, noUsers, xUser, yUser, minRate, g);
         fitness = minZ;
        pbest_position(i,:)=partical_position(i,:); %pbest = initial pos
        pbest_value(i) = fitness;

        if (fitness>gbest_value)
            gbest_value=fitness;
            gbest_position=partical_position(i,:); %gbest = best of pbesst
        end
     end

    %%PSO main loop
    for it=1:max_iteration
        convergence_curve(it) = gbest_value;
        w = w_max - (w_max-w_min)*it/max_iteration;
        for i=1:num_partical
             r1=rand();r2=rand();
             %update velocity
             partical_velocity(i,:)= w * partical_velocity(i,:) ...
                                    + c1*r1*(pbest_position(i,:)-partical_position(i,:))...
                                    + c2*r2*(gbest_position - partical_position(i,:));
             %update pos
             partical_position(i,:) = partical_position(i,:)+partical_velocity(i,:);
             % refresh the position if it out of range
             partical_position(i, 1) = min(max(partical_position(i, 1), dx_min), dx_max);
             partical_position(i, 2) = min(max(partical_position(i, 2), dz_min), dz_max);
             % judging with fitness func 
             vars = partical_position(i,:);
             [minZ, ~] = objective_function_positionUpdate_3D(vars, xUAV, yUAV, zUAV, noUsers, xUser, yUser, minRate, g);
            fitness = minZ;

             %pbest update
             if (fitness>pbest_value(i))
                pbest_value(i)=fitness;
                pbest_position(i,:)=partical_position(i,:); 
             end
               %gbest_update
             if (fitness>gbest_value)
                gbest_value=fitness;
                gbest_position=partical_position(i,:); 
             end
         end
     end
updatedPosition.position = gbest_position;
updatedPosition.minRate = gbest_value;
end