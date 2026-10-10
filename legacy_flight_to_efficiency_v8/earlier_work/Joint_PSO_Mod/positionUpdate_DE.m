function updatedPosition = positionUpdate_DE(xUAV, yUAV, zUAV, minRate, noUsers, xUser, yUser, g)
    %% 1. CẤU HÌNH THÔNG SỐ DE
    num_pop = 30;           
    max_iter = 50;          
    F = 0.5;                
    CR = 0.8;               
    
    %% 2. RÀNG BUỘC KHÔNG GIAN
    dx_min = max(-500, 0 - xUAV);
    dx_max = min(500, 2000 - xUAV);
    dz_min = 100 - zUAV;
    dz_max = 300 - zUAV;
    
    %% 3. KHỞI TẠO QUẦN THỂ
    pop = zeros(num_pop, 2);                 
    fitness_pop = -inf * ones(num_pop, 1);   
    gbest_pos = [0, 0];                      
    gbest_val = -inf;                        
    
    for i = 1:num_pop
        pop(i, 1) = dx_min + rand() * (dx_max - dx_min);
        pop(i, 2) = dz_min + rand() * (dz_max - dz_min);
        
        % Gọi hàm mục tiêu Không SWIPT
        vars = pop(i, :);
        [minZ, ~] = objective_function_positionUpdate_3D(vars, xUAV, yUAV, zUAV, noUsers, xUser, yUser, minRate, g);
        fitness_pop(i) = minZ; 
        
        if fitness_pop(i) > gbest_val
            gbest_val = fitness_pop(i);
            gbest_pos = pop(i, :);
        end
    end
    
    %% 4. VÒNG LẶP TIẾN HÓA DE 
    for iter = 1:max_iter
        for i = 1:num_pop
            idxs = randperm(num_pop, 4);
            idxs(idxs == i) = []; 
            r1 = idxs(1); r2 = idxs(2); r3 = idxs(3);
            
            % Đột biến (Mutation)
            v = pop(r1, :) + F * (pop(r2, :) - pop(r3, :));
            v(1) = min(max(v(1), dx_min), dx_max);
            v(2) = min(max(v(2), dz_min), dz_max);
            
            % Lai ghép (Crossover)
            u = zeros(1, 2);
            j_rand = randi(2); 
            for j = 1:2
                if rand() <= CR || j == j_rand
                    u(j) = v(j);       
                else
                    u(j) = pop(i, j);  
                end
            end
            
            % Chọn lọc (Selection) Không SWIPT
            vars = u;
            [minZ, ~] = objective_function_positionUpdate_3D(vars, xUAV, yUAV, zUAV, noUsers, xUser, yUser, minRate, g);
            fitness_u = minZ;
            
            if fitness_u > fitness_pop(i)
                pop(i, :) = u;
                fitness_pop(i) = fitness_u;
                if fitness_u > gbest_val
                    gbest_val = fitness_u;
                    gbest_pos = u;
                end
            end
        end
    end
    
    %% 5. TRẢ KẾT QUẢ VỀ
    updatedPosition.position = gbest_pos; 
    updatedPosition.minRate = gbest_val;
end