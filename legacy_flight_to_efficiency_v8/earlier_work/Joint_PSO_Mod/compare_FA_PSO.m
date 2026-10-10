clc;
clear variables;
close all;

%% Simulation Environment
enWidth = 2000;             
enLength = 2000;            
enHeight = 320;             
maxHeighUAV = 300;          
minHeighUAV = 50;           
noUsers = 3;                
noBS = 3;                   
noUAV = 1;                  

%% Users, Base Stations and UAV Position
% UAV Position
for i=1:noUAV
    xUAV_S(i) = 1000;       
    yUAV_S(i) = enLength;      
    zUAV_S(i) = 200;
end

% UAV End Position
for i=1:noUAV
    xUAV_E(i) = 1000;       
    yUAV_E(i) = 0;      
    zUAV_E(i) = 200;
end

% UAV Position (Moving)
for i=1:noUAV
    xUAV(i) = 1000;       
    yUAV(i) = enLength;      
    zUAV(i) = zUAV_S(i);   
end

% BS positions
xBS = [2000,0,2000];
yBS = [2000,1000,0];
zBS = [20, 30, 25];

% Users' posision
for i=1:noUsers
    xUser(i) = randi([enWidth/4, 3*enWidth/4]);      
    yUser(i) = randi([enLength/4, 3*enLength/4]);     
    zUser(i) = 0;                   
end

%% Figure Plot in Initial State
figure,
userPlot = plot3(xUser,yUser,zUser,'k*','linewidth',3); hold on;
for o=1:noUsers
    textUsers(o) = text(xUser(o)-10,yUser(o)-10,zUser(o)+10,['U',num2str(o)],'FontSize', 8);
end

plot3(xUAV_S, yUAV_S, zUAV_S, 'kh','linewidth', 3);
plot3(xUAV_E, yUAV_E, zUAV_E, 'kh','linewidth', 3);

plot3(xBS, yBS, zBS, 'k^','linewidth', 3);
for o=1:noBS
    plot3([xBS(o) xBS(o)], [yBS(o) yBS(o)],[zBS(o) 0], 'k-','linewidth', 1); drawnow
    text(xBS(o) + 20, yBS(o) + 10, zBS(o) + 10,['BS', num2str(o)],'FontSize', 8);
end

for i = 1:noUAV
    plot3([xUAV_S(i) xUAV_E(i)], [yUAV_S(i) yUAV_E(i)],[zUAV_S(i) zUAV_E(i)], 'y--','linewidth', 0.5); drawnow
end

mx = (zUAV_S - zUAV_E)/(yUAV_S - yUAV_E);
c = zUAV_S - mx*yUAV_S;

xlim([0 2050]); ylim([0 2050]); zlim([0 320]);
xlabel('Width (m)'); ylabel('Length (m)'); zlabel('Height (m)');
grid on; hold on; drawnow

index = 1;

%% Information for path loss & Rician Model
eta = 2.5;              
b_0dB = -50;            
b_0 = db2pow(b_0dB);    
k = 0.01;               
K_min = 4;      
K_max = 12;     
A1 = db2pow(K_min);
A2 = (2/pi)*log((db2pow(K_max))/A1);
g = sqrt(1/2)*(randn(1,1)+1i*randn(1,1));
% Biến lưu thời gian chạy và đường cong hội tụ
time_FA = zeros(1, 21);
time_PSO = zeros(1, 21);

% Ta sẽ chọn 1 bước bất kỳ (ví dụ bước index = 10) để trích xuất đường cong hội tụ
step_to_extract_convergence = 10; 
conv_FA_sample = [];
conv_PSO_sample = [];
%% Main Simulation Loop
for j = enLength:-100:0
    for i=1:noUAV
        % --- Baseline (No Opt) ---
        zUAV(i) = mx*j + c;
        yUAV(i) = j;
        plot3(xUAV(i), yUAV(i), zUAV(i), 'r+','linewidth', 0.5); hold on;

        % Channels & Rates for Baseline
        for m=1:noUsers
            groundDisUAV_User(i,m) = sqrt((xUAV(i)-xUser(m))^2 + (yUAV(i)-yUser(m))^2);
            DisUAV_User(i,m) = sqrt(groundDisUAV_User(i,m)^2 + zUAV(i)^2);
            angleUAV_User(i,m) = atan(zUAV(i)/groundDisUAV_User(i,m))*(180/pi);
            pow_LoS = b_0*(DisUAV_User(i,m)^(-eta));
            K_UAV_User(i,m) = A1*exp(A2*angleUAV_User(i,m)*(pi/180));
            g_UAV_User(i,m) = sqrt(K_UAV_User(i,m)/(1+K_UAV_User(i,m)))*g + sqrt(1/(1+K_UAV_User(i,m)))*g;
            h_UAV_Users(index,i,m) = sqrt(pow_LoS)*g_UAV_User(i,m);
        end
        [pow_coef_array_ch(index,:), pow_coef_array_fr(index,:)] = findPowCoeff(abs(h_UAV_Users(index,i,:)),noUsers);
        [achievableRate_ch(index,:), ~] = findAchievableRate(h_UAV_Users(index,i,:),pow_coef_array_ch(index,:),pow_coef_array_fr(index,:),noUsers);
        
        minRate = min(achievableRate_ch(index,:));
        
        % --- Optimization Step: FA and PSO ---
        % --- Optimization Step: FA and PSO ---
        if index > 1 && index < 21
            
            % --- ĐO THỜI GIAN FA ---
            tic; % Bắt đầu bấm giờ
            [pos_FA, curve_FA] = positionUpdate_FA(xUAV(i),yUAV(i),zUAV(i),minRate,noUsers,xUser,yUser,g);
            time_FA(index) = toc; % Dừng bấm giờ và lưu lại
            
            up_xUAV_FA(index,i) = xUAV(i) + pos_FA.position(1);
            up_yUAV_FA(index,i) = yUAV(i);
            up_zUAV_FA(index,i) = zUAV(i) + pos_FA.position(2);
            
            % --- ĐO THỜI GIAN PSO ---
            tic; % Bắt đầu bấm giờ
            [pos_PSO, curve_PSO] = positionUpdate_PSO_selfcode(xUAV(i),yUAV(i),zUAV(i),minRate,noUsers,xUser,yUser,g);
            time_PSO(index) = toc; % Dừng bấm giờ và lưu lại
            
            up_xUAV_PSO(index,i) = xUAV(i) + pos_PSO.position(1);
            up_yUAV_PSO(index,i) = yUAV(i);
            up_zUAV_PSO(index,i) = zUAV(i) + pos_PSO.position(2);

            % Lưu lại mẫu đường cong hội tụ tại 1 bước cụ thể để vẽ biểu đồ
            if index == step_to_extract_convergence
                conv_FA_sample = curve_FA;
                conv_PSO_sample = curve_PSO;
            end
        else
            % Default
            up_xUAV_FA(index,i) = xUAV(i); up_yUAV_FA(index,i) = yUAV(i); up_zUAV_FA(index,i) = zUAV(i);
            up_xUAV_PSO(index,i) = xUAV(i); up_yUAV_PSO(index,i) = yUAV(i); up_zUAV_PSO(index,i) = zUAV(i);
        end
        
        % Plotting 3D Trajectories
        plot3(up_xUAV_FA(index,i), up_yUAV_FA(index,i), up_zUAV_FA(index,i), 'gh','linewidth', 0.5); hold on;
        plot3(up_xUAV_PSO(index,i), up_yUAV_PSO(index,i), up_zUAV_PSO(index,i), 'bh','linewidth', 0.5); hold on;
        
        if index > 1 
            plot3([up_xUAV_FA(index-1,i) up_xUAV_FA(index,i)], [up_yUAV_FA(index-1,i) up_yUAV_FA(index,i)], [up_zUAV_FA(index-1,i) up_zUAV_FA(index,i)], 'g--','linewidth', 0.5); 
            plot3([up_xUAV_PSO(index-1,i) up_xUAV_PSO(index,i)], [up_yUAV_PSO(index-1,i) up_yUAV_PSO(index,i)], [up_zUAV_PSO(index-1,i) up_zUAV_PSO(index,i)], 'b--','linewidth', 0.5); drawnow
        end
        
        % --- Evaluate FA Metrics ---
        for m=1:noUsers
            groundDisUAV_User_FA = sqrt((up_xUAV_FA(index,i)-xUser(m))^2 + (up_yUAV_FA(index,i)-yUser(m))^2);
            DisUAV_User_FA = sqrt(groundDisUAV_User_FA^2 + up_zUAV_FA(index,i)^2);
            angleUAV_User_FA = atan(up_zUAV_FA(index,i)/groundDisUAV_User_FA)*(180/pi);
            pow_LoS_FA = b_0*(DisUAV_User_FA^(-eta));
            K_UAV_User_FA = A1*exp(A2*angleUAV_User_FA*(pi/180));
            g_UAV_User_FA = sqrt(K_UAV_User_FA/(1+K_UAV_User_FA))*g + sqrt(1/(1+K_UAV_User_FA))*g;
            h_UAV_Users_FA(index,i,m) = sqrt(pow_LoS_FA)*g_UAV_User_FA;
        end
        [pow_coef_ch_FA, pow_coef_fr_FA] = findPowCoeff(abs(h_UAV_Users_FA(index,i,:)),noUsers);
        [achRate_ch_FA, ~] = findAchievableRate(h_UAV_Users_FA(index,i,:),pow_coef_ch_FA,pow_coef_fr_FA,noUsers);
        
        % --- Evaluate PSO Metrics ---
        for m=1:noUsers
            groundDisUAV_User_PSO = sqrt((up_xUAV_PSO(index,i)-xUser(m))^2 + (up_yUAV_PSO(index,i)-yUser(m))^2);
            DisUAV_User_PSO = sqrt(groundDisUAV_User_PSO^2 + up_zUAV_PSO(index,i)^2);
            angleUAV_User_PSO = atan(up_zUAV_PSO(index,i)/groundDisUAV_User_PSO)*(180/pi);
            pow_LoS_PSO = b_0*(DisUAV_User_PSO^(-eta));
            K_UAV_User_PSO = A1*exp(A2*angleUAV_User_PSO*(pi/180));
            g_UAV_User_PSO = sqrt(K_UAV_User_PSO/(1+K_UAV_User_PSO))*g + sqrt(1/(1+K_UAV_User_PSO))*g;
            h_UAV_Users_PSO(index,i,m) = sqrt(pow_LoS_PSO)*g_UAV_User_PSO;
        end
        [pow_coef_ch_PSO, pow_coef_fr_PSO] = findPowCoeff(abs(h_UAV_Users_PSO(index,i,:)),noUsers);
        [achRate_ch_PSO, ~] = findAchievableRate(h_UAV_Users_PSO(index,i,:),pow_coef_ch_PSO,pow_coef_fr_PSO,noUsers);
        
        % Save Min Rates for Comparison
        minAchRate_Base(index) = min(achievableRate_ch(index,:));
        minAchRate_FA(index) = min(achRate_ch_FA(1,:));
        minAchRate_PSO(index) = min(achRate_ch_PSO(1,:));
    end
    index = index + 1;
end

%% Plotting Comparison Results
steps = 1:21;

% 1. So sánh Minimum Achievable Rate
figure;
plot(steps, minAchRate_Base(:), 'r--o', 'linewidth', 1.5); hold on;
plot(steps, minAchRate_FA(:), 'g-^', 'linewidth', 1.5);
plot(steps, minAchRate_PSO(:), 'b-s', 'linewidth', 1.5);

title('Comparison of Minimum Achievable Rate: Baseline vs FA vs PSO');
xlim([1 21]);
xlabel('Steps');
ylabel('Achievable Rate in bps');
legend('No Optimization', 'Optimized (FA)', 'Optimized (PSO)', 'Location', 'best');
grid on;

% Lưu ý: Code đã lược bỏ phần vẽ biểu đồ của các Users/BS riêng lẻ để tập trung 
% vào so sánh mục tiêu chính (Min Rate). Bạn có thể thêm lại nếu cần khảo sát sâu hơn.
%% ---------------- ĐÁNH GIÁ VÀ SO SÁNH THUẬT TOÁN ---------------- %%

% 1. BIỂU ĐỒ THỜI GIAN THỰC THI (COMPUTATIONAL COST)
figure;
total_time_FA = sum(time_FA);
total_time_PSO = sum(time_PSO);

% Vẽ biểu đồ thanh (Bar chart)
bar_data = [total_time_FA, total_time_PSO];
b = bar(bar_data, 'FaceColor', 'flat');
b.CData(1,:) = [0.4660 0.6740 0.1880]; % Màu xanh lá cho FA
b.CData(2,:) = [0 0.4470 0.7410];      % Màu xanh dương cho PSO

set(gca, 'xticklabel', {'Firefly Algorithm (FA)', 'Particle Swarm Optimization (PSO)'});
ylabel('Total Execution Time (seconds)');
title(sprintf('Computational Cost Comparison (20 steps)\nFA: %.2fs | PSO: %.2fs', total_time_FA, total_time_PSO));
grid on;

% 2. ĐƯỜNG CONG HỘI TỤ (CONVERGENCE CURVE)
% Kiểm tra xem đã lấy được mẫu chưa
if ~isempty(conv_FA_sample) && ~isempty(conv_PSO_sample)
    figure;
    iterations = 1:length(conv_FA_sample);
    
    plot(iterations, conv_FA_sample, 'g-^', 'LineWidth', 1.5, 'MarkerIndices', 1:5:length(conv_FA_sample)); hold on;
    plot(iterations, conv_PSO_sample, 'b-o', 'LineWidth', 1.5, 'MarkerIndices', 1:5:length(conv_PSO_sample));
    
    xlabel('Iteration');
    ylabel('Fitness Value (Minimum Achievable Rate)');
    title(sprintf('Convergence Speed Comparison (Sampled at Step %d)', step_to_extract_convergence));
    legend('FA Convergence', 'PSO Convergence', 'Location', 'best');
    grid on;
end