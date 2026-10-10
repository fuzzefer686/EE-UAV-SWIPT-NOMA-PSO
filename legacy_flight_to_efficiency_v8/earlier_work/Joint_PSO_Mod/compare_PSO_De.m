clc;
clear variables;
close all;

%% ========================================================================
%  1. KHỞI TẠO MÔI TRƯỜNG VÀ VỊ TRÍ
%  ========================================================================
enWidth = 2000; enLength = 2000; enHeight = 320;
noUsers = 10; noBS = 5; noUAV = 1;
step_size = 100;
nums_step = (enLength/step_size)+1
% UAV Start & End
xUAV_S = 1000; yUAV_S = enLength; zUAV_S = 200;
xUAV_E = 1000; yUAV_E = 0;        zUAV_E = 200;
xUAV = xUAV_S; yUAV = yUAV_S;     zUAV = zUAV_S;

% BS and GUs
% xBS = [2000, 0, 2000]; yBS = [2000, 1000, 0]; zBS = [20, 30, 25]; 
% Fixed at 3 BSs, testing with more BSs below
%
for bm=1:noBS
    xBS(bm) = randi([0, enWidth]);          
    yBS(bm) = randi([0, enLength]);         
    zBS(bm) = randi([0, 40]);
end
for i=1:noUsers
    xUser(i) = randi([0, enWidth]);      % Mở rộng phân tán User
    yUser(i) = randi([0, enLength]);     
    zUser(i) = 0;                   
end

%% ========================================================================
%  2. THIẾT LẬP KÊNH TRUYỀN VÀ BIỂU ĐỒ 3D
%  ========================================================================
eta = 2.5; b_0 = db2pow(-50); k = 0.01;               
A1 = db2pow(4); A2 = (2/pi)*log((db2pow(12))/A1);
g = sqrt(1/2)*(randn(1,1)+1i*randn(1,1));

figure('Name', 'Trường đua 3D: PSO vs DE', 'NumberTitle', 'off');
plot3(xUser,yUser,zUser,'k*','linewidth',3); hold on;
for o=1:noUsers, text(xUser(o)-10,yUser(o)-10,10,['U',num2str(o)]); end
plot3([xUAV_S, xUAV_E], [yUAV_S, yUAV_E], [zUAV_S, zUAV_E], 'k--','linewidth', 1);
plot3(xBS, yBS, zBS, 'k^','linewidth', 3);
for o=1:noBS, text(xBS(o)+20, yBS(o)+10, zBS(o)+10,['BS', num2str(o)]); end
grid on; xlim([0 2050]); ylim([0 2050]); zlim([0 320]);
xlabel('Width (m)'); ylabel('Length (m)'); zlabel('Height (m)');

mx = (zUAV_S - zUAV_E)/(yUAV_S - yUAV_E); c = zUAV_S - mx*yUAV_S;
index = 1;

%% ========================================================================
%  3. VÒNG LẶP MÔ PHỎNG CHÍNH (BẮT ĐẦU CHẠY ĐUA)
%  ========================================================================
for j = enLength:-step_size:0
    zUAV = mx*j + c; yUAV = j;
    
    % --- Tính toán kênh truyền gốc (Predefined Path) ---
    for bm=1:noBS
        DisUAV_BS(bm) = sqrt((xUAV-xBS(bm))^2 + (yUAV-yBS(bm))^2 + (zBS(bm)-zUAV)^2);
        ang_BS = atan(abs(zBS(bm)-zUAV)/sqrt((xUAV-xBS(bm))^2 + (yUAV-yBS(bm))^2))*(180/pi);
        K_BS = A1*exp(A2*ang_BS*(pi/180));
        h_UAV_BS(index,bm) = sqrt(b_0*(DisUAV_BS(bm)^(-eta))) * (sqrt(K_BS/(1+K_BS))*g + sqrt(1/(1+K_BS))*g);
    end
    for m=1:noUsers
        DisUAV_User(m) = sqrt((xUAV-xUser(m))^2 + (yUAV-yUser(m))^2 + zUAV^2);
        ang_User = atan(zUAV/sqrt((xUAV-xUser(m))^2 + (yUAV-yUser(m))^2))*(180/pi);
        K_User = A1*exp(A2*ang_User*(pi/180));
        h_UAV_Users(index,m) = sqrt(b_0*(DisUAV_User(m)^(-eta))) * (sqrt(K_User/(1+K_User))*g + sqrt(1/(1+K_User))*g);
    end
    
    [pow_ch, pow_fr] = findPowCoeff(abs(h_UAV_Users(index,:)), noUsers);
    [Rate_SWIPT, ~] = findAchievableRate_SWIPT(h_UAV_Users(index,:), h_UAV_BS(index,:), pow_ch, pow_fr, noUsers);
    minRate_Base = min(Rate_SWIPT);
    minAchRate_Base(index) = minRate_Base;

    % --- Đưa PSO và DE vào tối ưu hóa ---
    % --- Đưa PSO và DE vào tối ưu hóa ---
    if index > 1 && index < 21
        % Bấm giờ cho PSO
        tic;
        up_PSO = positionUpdate_PSO_SWIPT(xUAV, yUAV, zUAV, xBS, yBS, zBS, minRate_Base, noUsers, xUser, yUser, g, noBS);
        time_PSO(index) = toc; % Lưu thời gian chạy của PSO
        
        xPSO(index) = xUAV + up_PSO.position(1); zPSO(index) = zUAV + up_PSO.position(2); yPSO(index) = yUAV;
        
        % Bấm giờ cho DE
        tic;
        up_DE = positionUpdate_DE_SWIPT(xUAV, yUAV, zUAV, xBS, yBS, zBS, minRate_Base, noUsers, xUser, yUser, g, noBS);
        time_DE(index) = toc; % Lưu thời gian chạy của DE
        
        xDE(index) = xUAV + up_DE.position(1); zDE(index) = zUAV + up_DE.position(2); yDE(index) = yUAV;
    else
        % Điểm bắt đầu và kết thúc không chạy thuật toán nên thời gian = 0
        time_PSO(index) = 0;
        time_DE(index) = 0;
        
        xPSO(index) = xUAV; zPSO(index) = zUAV; yPSO(index) = yUAV;
        xDE(index) = xUAV;  zDE(index) = zUAV;  yDE(index) = yUAV;
    end

    % Vẽ trực tiếp quỹ đạo
    if index > 1 
        plot3([xPSO(index-1) xPSO(index)], [yPSO(index-1) yPSO(index)], [zPSO(index-1) zPSO(index)], 'r-o','linewidth', 1.5); 
        plot3([xDE(index-1) xDE(index)], [yDE(index-1) yDE(index)], [zDE(index-1) zDE(index)], 'b-*','linewidth', 1.5); 
        drawnow;
    end

    % --- Tính lại Rate cho 2 tọa độ vừa tìm được ---
    for bm=1:noBS
        % PSO
        Dis_PSO = sqrt((xPSO(index)-xBS(bm))^2 + (yPSO(index)-yBS(bm))^2 + (zBS(bm)-zPSO(index))^2);
        ang_PSO = atan(abs(zBS(bm)-zPSO(index))/sqrt((xPSO(index)-xBS(bm))^2 + (yPSO(index)-yBS(bm))^2))*(180/pi);
        K_PSO = A1*exp(A2*ang_PSO*(pi/180));
        h_BS_PSO(bm) = sqrt(b_0*(Dis_PSO^(-eta))) * (sqrt(K_PSO/(1+K_PSO))*g + sqrt(1/(1+K_PSO))*g);
        
        % DE
        Dis_DE = sqrt((xDE(index)-xBS(bm))^2 + (yDE(index)-yBS(bm))^2 + (zBS(bm)-zDE(index))^2);
        ang_DE = atan(abs(zBS(bm)-zDE(index))/sqrt((xDE(index)-xBS(bm))^2 + (yDE(index)-yBS(bm))^2))*(180/pi);
        K_DE = A1*exp(A2*ang_DE*(pi/180));
        h_BS_DE(bm) = sqrt(b_0*(Dis_DE^(-eta))) * (sqrt(K_DE/(1+K_DE))*g + sqrt(1/(1+K_DE))*g);
    end

    for m=1:noUsers
        % PSO
        Dis_PSO_U = sqrt((xPSO(index)-xUser(m))^2 + (yPSO(index)-yUser(m))^2 + zPSO(index)^2);
        ang_PSO_U = atan(zPSO(index)/sqrt((xPSO(index)-xUser(m))^2 + (yPSO(index)-yUser(m))^2))*(180/pi);
        K_PSO_U = A1*exp(A2*ang_PSO_U*(pi/180));
        h_U_PSO(m) = sqrt(b_0*(Dis_PSO_U^(-eta))) * (sqrt(K_PSO_U/(1+K_PSO_U))*g + sqrt(1/(1+K_PSO_U))*g);
        
        % DE
        Dis_DE_U = sqrt((xDE(index)-xUser(m))^2 + (yDE(index)-yUser(m))^2 + zDE(index)^2);
        ang_DE_U = atan(zDE(index)/sqrt((xDE(index)-xUser(m))^2 + (yDE(index)-yUser(m))^2))*(180/pi);
        K_DE_U = A1*exp(A2*ang_DE_U*(pi/180));
        h_U_DE(m) = sqrt(b_0*(Dis_DE_U^(-eta))) * (sqrt(K_DE_U/(1+K_DE_U))*g + sqrt(1/(1+K_DE_U))*g);
    end
    
    % Chốt Rate PSO
    [pow_ch_PSO, pow_fr_PSO] = findPowCoeff(abs(h_U_PSO), noUsers);
    [Rate_PSO, ~] = findAchievableRate_SWIPT(h_U_PSO, h_BS_PSO, pow_ch_PSO, pow_fr_PSO, noUsers);
    minAchRate_PSO(index) = min(Rate_PSO);

    % Chốt Rate DE
    [pow_ch_DE, pow_fr_DE] = findPowCoeff(abs(h_U_DE), noUsers);
    [Rate_DE, ~] = findAchievableRate_SWIPT(h_U_DE, h_BS_DE, pow_ch_DE, pow_fr_DE, noUsers);
    minAchRate_DE(index) = min(Rate_DE);

    index = index + 1;
end

legend('Users','Predefined Path','BSs', 'PSO Path (Red)', 'DE Path (Blue)', 'Location', 'northeast');

%% ========================================================================
%  4. VẼ BIỂU ĐỒ SO SÁNH HIỆU SUẤT CUỐI CÙNG
%  ========================================================================
steps = 1:nums_step;
figure('Name', 'Kết quả Benchmark: PSO vs DE', 'NumberTitle', 'off');
plot(steps, minAchRate_Base(:), 'k--o', 'linewidth', 1.5, 'MarkerSize', 6); hold on;
plot(steps, minAchRate_PSO(:), 'r-square', 'linewidth', 1.5, 'MarkerSize', 6);
plot(steps, minAchRate_DE(:), 'b-*', 'linewidth', 1.5, 'MarkerSize', 6);

title('So sánh Max-Min Rate: PSO vs DE (Mô hình SWIPT)')
xlim([1 nums_step]); xlabel('Steps'); ylabel('Achievable Rate in bps');
legend('Đường bay thẳng (Không tối ưu)', 'Thuật toán PSO (Màu Đỏ)', 'Thuật toán DE (Màu Xanh Dương)', 'Location', 'northwest');
grid on;
%% ========================================================================
%  5. VẼ BIỂU ĐỒ SO SÁNH THỜI GIAN THỰC THI (EXECUTION TIME)
%  ========================================================================
figure('Name', 'Thời gian xử lý: PSO vs DE', 'NumberTitle', 'off');

% Vẽ đường thời gian (bỏ qua điểm đầu và cuối vì bằng 0 để đồ thị đẹp hơn)
plot(steps(2:20), time_PSO(2:20), 'r-square', 'linewidth', 1.5, 'MarkerSize', 6); hold on;
plot(steps(2:20), time_DE(2:20), 'b-*', 'linewidth', 1.5, 'MarkerSize', 6);

title('So sánh Thời gian Xử lý tại mỗi bước: PSO vs DE')
xlim([2 20]); % Chỉ hiển thị các bước có chạy tối ưu hóa
xlabel('Steps (Các bước di chuyển của UAV)'); 
ylabel('Thời gian thực thi (Giây)');
legend('Thời gian chạy PSO (Màu Đỏ)', 'Thời gian chạy DE (Màu Xanh Dương)', 'Location', 'northwest');
grid on;

% Tính và in tổng thời gian ra Command Window
total_time_PSO = sum(time_PSO);
total_time_DE = sum(time_DE);
fprintf('--------------------------------------------------\n');
fprintf('TỔNG KẾT THỜI GIAN CHẠY (Cho toàn bộ %d bước):\n', length(steps)-2);
fprintf('Tổng thời gian PSO: %.4f giây\n', total_time_PSO);
fprintf('Tổng thời gian DE : %.4f giây\n', total_time_DE);
fprintf('--------------------------------------------------\n');