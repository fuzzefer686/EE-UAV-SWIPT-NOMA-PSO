function updatedPosition = positionUpdate_DE_SWIPT(xUAV, yUAV, zUAV, xBS, yBS, zBS, minRate, noUsers, xUser, yUser, g, noBS)
    %% 1. CẤU HÌNH THÔNG SỐ DE (Differential Evolution Parameters)
    num_pop = 50;           % Kích thước quần thể (tương đương num_particles)
    max_iter = 100;          % Số thế hệ lặp tối đa
    F = 0.5;                % Hệ số đột biến (Mutation factor), khuyên dùng [0.4, 0.9]
    CR = 0.8;               % Tỷ lệ lai ghép (Crossover rate), khuyên dùng [0.7, 1.0]
    
    %% 2. RÀNG BUỘC KHÔNG GIAN (Mặt phẳng thẳng đứng)
    dx_min = max(-500, 0 - xUAV);
    dx_max = min(500, 2000 - xUAV);
    dz_min = 100 - zUAV;
    dz_max = 300 - zUAV;
    
    %% 3. KHỞI TẠO QUẦN THỂ
    pop = zeros(num_pop, 2);                 % Lưu tọa độ X, Z
    fitness_pop = -inf * ones(num_pop, 1);   % Lưu điểm số (minRate)
    
    gbest_pos = [0, 0];                      % Vị trí tốt nhất toàn cục
    gbest_val = -inf;                        % Điểm số cao nhất
    
    for i = 1:num_pop
        % Khởi tạo ngẫu nhiên vị trí ban đầu trong vùng cho phép
        pop(i, 1) = dx_min + rand() * (dx_max - dx_min);
        pop(i, 2) = dz_min + rand() * (dz_max - dz_min);
        
        % GỌI HÀM MỤC TIÊU CÓ SWIPT
        vars = pop(i, :);
        [minZ, ~] = objective_function_positionUpdate_3D_SWIPT(vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, minRate, g, noBS);
        fitness_pop(i) = minZ; 
        
        % Chốt cá thể xuất sắc nhất ngay từ đầu
        if fitness_pop(i) > gbest_val
            gbest_val = fitness_pop(i);
            gbest_pos = pop(i, :);
        end
    end
    
    %% 4. VÒNG LẶP TIẾN HÓA DE 
    for iter = 1:max_iter
        for i = 1:num_pop
            
            % a. CHỌN LỌC PHỤ HUYNH: Chọn 3 cá thể ngẫu nhiên khác nhau và khác i
            idxs = randperm(num_pop, 4);
            idxs(idxs == i) = []; % Loại bỏ cá thể hiện tại (i)
            r1 = idxs(1); r2 = idxs(2); r3 = idxs(3);
            
            % b. ĐỘT BIẾN (Mutation)
            % Tạo Donor vector: V = pop(r1) + F * (pop(r2) - pop(r3))
            v = pop(r1, :) + F * (pop(r2, :) - pop(r3, :));
            
            % Khóa biên (Cực kỳ quan trọng để vector đột biến không văng ra khỏi lồng)
            v(1) = min(max(v(1), dx_min), dx_max);
            v(2) = min(max(v(2), dz_min), dz_max);
            
            % c. LAI GHÉP (Crossover)
            % Tạo Trial vector: U
            u = zeros(1, 2);
            j_rand = randi(2); % Đảm bảo ít nhất 1 chiều (X hoặc Z) được đổi mới
            for j = 1:2
                if rand() <= CR || j == j_rand
                    u(j) = v(j);       % Nhận gen đột biến
                else
                    u(j) = pop(i, j);  % Giữ gen cũ
                end
            end
            
            % d. CHỌN LỌC KHẮT KHE (Selection)
            % Đánh giá điểm của phương án U vừa tạo ra
            vars = u;
            [minZ, ~] = objective_function_positionUpdate_3D_SWIPT(vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, minRate, g, noBS);
            fitness_u = minZ;
            
            % Chỉ thay thế nếu U thực sự tốt hơn (tốc độ cao hơn) phương án cũ
            if fitness_u > fitness_pop(i)
                pop(i, :) = u;
                fitness_pop(i) = fitness_u;
                
                % Cập nhật bảng vàng toàn cục
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