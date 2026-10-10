function updatedPosition = positionUpdate_PSO(xUAV, yUAV, zUAV, minRate, noUsers, xUser, yUser, g)
    num_particles = 30;     % Số lượng chim trong đàn (Số hạt)
    max_iter = 50;          % Số vòng lặp tối đa (Số lần đập cánh)
    w = 0.7;                % Trọng số quán tính
    c1 = 1.5;               % Hệ số nhận thức (pbest)
    c2 = 1.5;               % Hệ số xã hội (gbest)   
    
    %% Thiết lập giới hạn không gian bay
    % Ràng buộc trục X: Tạt ngang tối đa 500m và không bay ra ngoài [0, 2000]
    dx_min = max(-500, 0 - xUAV);
    dx_max = min(500, 2000 - xUAV);
    
    % Ràng buộc trục Z: Độ cao bắt buộc nằm trong [100, 300] 
    dz_min = 100 - zUAV;
    dz_max = 300 - zUAV;
    
    %% Khởi tạo bầy đàn
    particles_pos = zeros(num_particles, 2); % Tọa độ [delta_x, delta_z] của mỗi hạt
    particles_vel = zeros(num_particles, 2); % Vận tốc của mỗi hạt
    pbest_pos = zeros(num_particles, 2);     % Trí nhớ cá nhân: Tọa độ tốt nhất
    pbest_val = -inf * ones(num_particles, 1); % Trí nhớ cá nhân: Điểm số tốt nhất
    
    gbest_pos = [0, 0];                      % Trí nhớ bầy đàn: Tọa độ tốt nhất
    gbest_val = -inf;                        % Trí nhớ bầy đàn: Điểm số tốt nhất
    
    % Rải ngẫu nhiên đàn chim vào không gian
    for i = 1:num_particles
        particles_pos(i, 1) = dx_min + rand() * (dx_max - dx_min);
        particles_pos(i, 2) = dz_min + rand() * (dz_max - dz_min);
        particles_vel(i, :) = [0, 0]; % Ban đầu chưa bay nên vận tốc = 0
        
        % Đem tọa độ này đi chấm điểm bằng Hàm mục tiêu của tác giả
        vars = particles_pos(i, :);
        [minZ, ~] = objective_function_positionUpdate_3D(vars, xUAV, yUAV, zUAV, noUsers, xUser, yUser, minRate, g);
        fitness = minZ; % Điểm số chính là tốc độ mạng của người yếu nhất
        
        % Ghi nhớ lại pbest và gbest ban đầu
        pbest_pos(i, :) = particles_pos(i, :);
        pbest_val(i) = fitness;
        
        if fitness > gbest_val
            gbest_val = fitness;
            gbest_pos = particles_pos(i, :);
        end
    end
    
    %% PSO Main Loop
    for iter = 1:max_iter
        for i = 1:num_particles
            % A. Cập nhật Vận Tốc (Học hỏi từ pbest và gbest)
            r1 = rand(); r2 = rand(); % Yếu tố ngẫu nhiên
            particles_vel(i, :) = w * particles_vel(i, :) ...
                                + c1 * r1 * (pbest_pos(i, :) - particles_pos(i, :)) ...
                                + c2 * r2 * (gbest_pos - particles_pos(i, :));
                                
            % B. Cập nhật Vị Trí Mới
            particles_pos(i, :) = particles_pos(i, :) + particles_vel(i, :);
            
            % C. Bắt chim quay lại nếu bay ra khỏi giới hạn (Boundary check)
            particles_pos(i, 1) = min(max(particles_pos(i, 1), dx_min), dx_max);
            particles_pos(i, 2) = min(max(particles_pos(i, 2), dz_min), dz_max);
            
            % D. Chấm điểm lại vị trí mới
            vars = particles_pos(i, :);
            [minZ, ~] = objective_function_positionUpdate_3D(vars, xUAV, yUAV, zUAV, noUsers, xUser, yUser, minRate, g);
            fitness = minZ;
            
            % E. Cập nhật lại trí nhớ cá nhân (pbest)
            if fitness > pbest_val(i)
                pbest_val(i) = fitness;
                pbest_pos(i, :) = particles_pos(i, :);
            end
            
            % F. Cập nhật lại trí nhớ bầy đàn (gbest)
            if fitness > gbest_val
                gbest_val = fitness;
                gbest_pos = particles_pos(i, :);
            end
        end
    end
    
    %% Trả kết quả
    updatedPosition.position = gbest_pos; % Trả về bước đi [delta_x, delta_z] ngon nhất
    updatedPosition.minRate = gbest_val;
end