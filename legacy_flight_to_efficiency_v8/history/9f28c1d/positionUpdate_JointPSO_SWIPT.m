function updatedPosition = positionUpdate_JointPSO_SWIPT(xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, g_NLoS_Users, g_NLoS_BS, noBS)
    
    %% CẤU HÌNH THÔNG SỐ ĐÀN CHIM
    num_particles = 70;
    max_iter = 200;
    w = 0.7;
    c1 = 1.5;
    c2 = 1.5;
    
    %% RÀNG BUỘC KHÔNG GIAN (Vị trí & Công suất)
    x_margin = 75;  
    z_min_abs = 15;
    z_max_abs = 45;
    
    dx_min = max(-x_margin, 75 - xUAV);
    dx_max = min( x_margin, 225 - xUAV);
    
    dz_min = z_min_abs - zUAV;
    dz_max = z_max_abs - zUAV;
    
    p_min = 0.001;
    p_max = 1.0;
    
    %% KHỞI TẠO BẦY ĐÀN
    particles_pos = zeros(num_particles, 2 + noUsers);   % [dx, dz, p1, p2, p3]
    particles_vel = zeros(num_particles, 2 + noUsers);
    pbest_pos = zeros(num_particles, 2 + noUsers);
    pbest_val = -inf * ones(num_particles, 1);
    
    gbest_pos = zeros(1, 2 + noUsers);
    gbest_val = -inf;
    
    for i = 1:num_particles
        particles_pos(i, 1) = dx_min + rand() * (dx_max - dx_min);
        particles_pos(i, 2) = dz_min + rand() * (dz_max - dz_min);
        particles_pos(i, 3:end) = p_min + rand(1, noUsers) * (p_max - p_min);
        particles_vel(i, :) = zeros(1, 2 + noUsers);
        
        vars = particles_pos(i, :);
        [minZ, ~] = objective_function_Joint_SWIPT(vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, g_NLoS_Users, g_NLoS_BS, noBS);
        fitness = minZ;
        
        pbest_pos(i, :) = particles_pos(i, :);
        pbest_val(i) = fitness;
        
        if fitness > gbest_val
            gbest_val = fitness;
            gbest_pos = particles_pos(i, :);
        end
    end
    
    %% VÒNG LẶP TỐI ƯU PSO
    for iter = 1:max_iter
        for i = 1:num_particles
            r1 = rand();
            r2 = rand();
            
            particles_vel(i, :) = w * particles_vel(i, :) ...
                                + c1 * r1 * (pbest_pos(i, :) - particles_pos(i, :)) ...
                                + c2 * r2 * (gbest_pos - particles_pos(i, :));
                                
            particles_pos(i, :) = particles_pos(i, :) + particles_vel(i, :);
            
            % Khóa biên
            particles_pos(i, 1) = min(max(particles_pos(i, 1), dx_min), dx_max);
            particles_pos(i, 2) = min(max(particles_pos(i, 2), dz_min), dz_max);
            particles_pos(i, 3:end) = min(max(particles_pos(i, 3:end), p_min), p_max);
            
            vars = particles_pos(i, :);
            [minZ, ~] = objective_function_Joint_SWIPT(vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, g_NLoS_Users, g_NLoS_BS, noBS);
            fitness = minZ;
            
            if fitness > pbest_val(i)
                pbest_val(i) = fitness;
                pbest_pos(i, :) = particles_pos(i, :);
            end
            
            if fitness > gbest_val
                gbest_val = fitness;
                gbest_pos = particles_pos(i, :);
            end
        end
    end
    
    %% TRẢ KẾT QUẢ
    updatedPosition.position = gbest_pos(1:2);

    best_raw_p = max(gbest_pos(3:end), 1e-12);
    updatedPosition.alpha_coeffs = best_raw_p / sum(best_raw_p);   % alpha theo user gốc

    updatedPosition.minRate = gbest_val;   % fitness sau penalty
end