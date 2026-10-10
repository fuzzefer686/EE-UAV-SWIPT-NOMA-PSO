function updatedPosition = positionUpdate_PSO_SWIPT(xUAV, yUAV, zUAV, xBS, yBS, zBS, minRate, noUsers, xUser, yUser, fading, noBS, nextX)
    p = paperParameters();
    %% 1. CẤU HÌNH THÔNG SỐ ĐÀN CHIM (PSO Parameters)
    num_particles = 30;     
    max_iter = 50;          
    w = 0.7;                
    c1 = 1.5;               
    c2 = 1.5;               
    
    %% 2. RÀNG BUỘC KHÔNG GIAN 
    dx_min = max(-p.xStepMax, 0 - xUAV);
    dx_max = min(p.xStepMax, p.environmentWidth - xUAV);
    if nargin >= 13 && ~isempty(nextX)
        dx_min = max(dx_min, nextX - p.xStepMax - xUAV);
        dx_max = min(dx_max, nextX + p.xStepMax - xUAV);
    end
    dz_min = p.zMin - zUAV;
    dz_max = p.zMax - zUAV;
    
    %% 3. KHỞI TẠO BẦY ĐÀN
    particles_pos = zeros(num_particles, 2); 
    particles_vel = zeros(num_particles, 2); 
    pbest_pos = zeros(num_particles, 2);     
    pbest_val = -inf * ones(num_particles, 1); 
    
    gbest_pos = [0, 0];                      
    gbest_val = -inf;                        
    
    for i = 1:num_particles
        particles_pos(i, 1) = dx_min + rand() * (dx_max - dx_min);
        particles_pos(i, 2) = dz_min + rand() * (dz_max - dz_min);
        particles_vel(i, :) = [0, 0]; 
        
        % GỌI HÀM MỤC TIÊU CÓ SWIPT (truyền thêm xBS, yBS, zBS, noBS)
        vars = particles_pos(i, :);
        [minZ, ~] = objective_function_positionUpdate_3D_SWIPT(vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, minRate, fading, noBS);
        fitness = minZ; 
        
        pbest_pos(i, :) = particles_pos(i, :);
        pbest_val(i) = fitness;
        
        if fitness > gbest_val
            gbest_val = fitness;
            gbest_pos = particles_pos(i, :);
        end
    end
    
    %% 4. VÒNG LẶP TỐI ƯU PSO
    for iter = 1:max_iter
        for i = 1:num_particles
            r1 = rand(); r2 = rand(); 
            particles_vel(i, :) = w * particles_vel(i, :) ...
                                + c1 * r1 * (pbest_pos(i, :) - particles_pos(i, :)) ...
                                + c2 * r2 * (gbest_pos - particles_pos(i, :));
                                
            particles_pos(i, :) = particles_pos(i, :) + particles_vel(i, :);
            
            % Khóa biên
            particles_pos(i, 1) = min(max(particles_pos(i, 1), dx_min), dx_max);
            particles_pos(i, 2) = min(max(particles_pos(i, 2), dz_min), dz_max);
            
            % Chấm điểm lại với hàm SWIPT
            vars = particles_pos(i, :);
            [minZ, ~] = objective_function_positionUpdate_3D_SWIPT(vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, minRate, fading, noBS);
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
    
    %% 5. TRẢ KẾT QUẢ VỀ
    updatedPosition.position = gbest_pos; 
    updatedPosition.minRate = gbest_val;
end
