function updatedPosition = positionUpdate_PSO_SWIPT(xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, g_NLoS_Users, g_NLoS_BS, noBS)

    %% CAU HINH PSO
    num_particles = 30;
    max_iter = 50;
    w = 0.7;
    c1 = 1.5;
    c2 = 1.5;

    %% RANG BUOC KHONG GIAN
    x_margin = 75;  
    z_min_abs = 15;
    z_max_abs = 45;
    
    dx_min = max(-x_margin, 75 - xUAV);
    dx_max = min( x_margin, 225 - xUAV);
    
    dz_min = z_min_abs - zUAV;
    dz_max = z_max_abs - zUAV;

    %% KHOI TAO BAY DAN
    particles_pos = zeros(num_particles, 2);
    particles_vel = zeros(num_particles, 2);
    pbest_pos = zeros(num_particles, 2);
    pbest_val = -inf * ones(num_particles, 1);

    gbest_pos = [0, 0];
    gbest_val = -inf;

    for i = 1:num_particles
        particles_pos(i,1) = dx_min + rand() * (dx_max - dx_min);
        particles_pos(i,2) = dz_min + rand() * (dz_max - dz_min);
        particles_vel(i,:) = [0, 0];

        vars = particles_pos(i,:);
        [minZ, ~] = objective_function_positionUpdate_3D_SWIPT( ...
            vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, ...
            noUsers, xUser, yUser, g_NLoS_Users, g_NLoS_BS, noBS);

        fitness = minZ;

        pbest_pos(i,:) = particles_pos(i,:);
        pbest_val(i) = fitness;

        if fitness > gbest_val
            gbest_val = fitness;
            gbest_pos = particles_pos(i,:);
        end
    end

    %% VONG LAP PSO
    for iter = 1:max_iter
        for i = 1:num_particles
            r1 = rand();
            r2 = rand();

            particles_vel(i,:) = w * particles_vel(i,:) ...
                + c1 * r1 * (pbest_pos(i,:) - particles_pos(i,:)) ...
                + c2 * r2 * (gbest_pos - particles_pos(i,:));

            particles_pos(i,:) = particles_pos(i,:) + particles_vel(i,:);

            % Khoa bien
            particles_pos(i,1) = min(max(particles_pos(i,1), dx_min), dx_max);
            particles_pos(i,2) = min(max(particles_pos(i,2), dz_min), dz_max);

            vars = particles_pos(i,:);
            [minZ, ~] = objective_function_positionUpdate_3D_SWIPT( ...
                vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, ...
                noUsers, xUser, yUser, g_NLoS_Users, g_NLoS_BS, noBS);

            fitness = minZ;

            if fitness > pbest_val(i)
                pbest_val(i) = fitness;
                pbest_pos(i,:) = particles_pos(i,:);
            end

            if fitness > gbest_val
                gbest_val = fitness;
                gbest_pos = particles_pos(i,:);
            end
        end
    end

    %% 5. KET QUA
    updatedPosition.position = gbest_pos;
    updatedPosition.minRate = gbest_val;
end