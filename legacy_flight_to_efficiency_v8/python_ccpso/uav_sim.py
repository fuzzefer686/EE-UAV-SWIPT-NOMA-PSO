"""
uav_sim.py: Mô hình hóa hệ thống UAV SWIPT-NOMA
Mô phỏng: Quỹ đạo UAV 3D, Kênh Rician fading, Thu hoạch năng lượng SWIPT,
          Phân bổ công suất NOMA SIC, và Hàm mục tiêu Max-Min Fairness.
Tương thích hoàn toàn với cấu hình và công thức của V8 trong MATLAB.
"""

import numpy as np


class UAVSimConfig:
    def __init__(self, main_seed=2026, no_users=5, no_bs=3):
        self.main_seed = main_seed
        self.no_users = no_users
        self.no_bs = no_bs

        # Không gian mô phỏng (mét)
        self.en_width = 300.0
        self.en_length = 300.0
        self.en_height = 60.0

        # Điểm đầu & cuối của UAV
        self.x_start = 150.0
        self.y_start = self.en_length  # 300
        self.z_start = 30.0

        self.x_end = 150.0
        self.y_end = 0.0
        self.z_end = 30.0

        # Vị trí trạm BS ban đầu [3 x 3]
        self.x_bs_init = np.array([300.0, 0.0, 300.0])
        self.y_bs_init = np.array([300.0, 150.0, 0.0])
        self.z_bs_init = np.array([20.0, 30.0, 25.0])

        # Ranh giới dịch chuyển của BS
        self.bs_margin = 50.0
        self.x_bs_min = np.maximum(0.0, self.x_bs_init - self.bs_margin)
        self.x_bs_max = np.minimum(self.en_width, self.x_bs_init + self.bs_margin)
        self.y_bs_min = np.maximum(0.0, self.y_bs_init - self.bs_margin)
        self.y_bs_max = np.minimum(self.en_length, self.y_bs_init + self.bs_margin)

        # Ranh giới không gian bay UAV
        self.x_min, self.x_max = 75.0, 225.0
        self.z_min, self.z_max = 15.0, 45.0
        self.dx_max = 75.0
        self.dz_max = 30.0

        # Phân đoạn bước bay: 300 -> 0 bước 15m (21 steps)
        self.steps_vec = np.arange(self.en_length, -1.0, -15.0)  # [300, 285, ..., 0]
        self.num_steps = len(self.steps_vec)  # 21
        self.n_internal = self.num_steps - 2   # 19

        # Thông số SWIPT
        self.P_r_dBm = 46.0
        self.P_r = (1e-3) * (10.0 ** (self.P_r_dBm / 10.0))  # Watts (~39.81 W)
        self.T_slot = 1e-6
        self.phi = 0.9
        self.eta = 0.9

        # Thông số kênh truyền
        self.B = 1e6  # Băng thông 1 MHz
        self.N0_dBm = -174.0 + 10.0 * np.log10(self.B)  # -114 dBm
        self.sigma2 = (1e-3) * (10.0 ** (self.N0_dBm / 10.0))  # Noise power in Watts

        self.eta_path = 2.5
        self.b0 = 10.0 ** (-30.0 / 10.0)  # -30 dB = 1e-3

        self.K_min = 4.0
        self.K_max = 12.0
        self.A1 = 10.0 ** (self.K_min / 10.0)
        self.A2 = (2.0 / np.pi) * np.log(10.0 ** (self.K_max / 10.0) / self.A1)
        self.g_los = 1.0

        # Ràng buộc công suất NOMA
        self.p_min = 1e-3
        self.p_max = 1.0

        # Hệ số phạt & trọng số Fitness
        self.big_penalty = 1e12
        self.lambda_mean = 0.05
        self.lambda_fair = 0.10

        # Số chiều hạt trong JointPSO (149D)
        self.d_pos = 2 * self.n_internal        # 38
        self.d_pow = self.num_steps * self.no_users  # 105
        self.d_bs  = 2 * self.no_bs             # 6
        self.D = self.d_pos + self.d_pow + self.d_bs  # 149

        # Khởi tạo kịch bản ngẫu nhiên theo main_seed
        self.init_scenario(self.main_seed)

    def init_scenario(self, seed):
        rng = np.random.RandomState(seed)
        # Sinh vị trí Users
        self.x_user = rng.randint(int(self.en_width / 4), int(3 * self.en_width / 4) + 1, size=self.no_users).astype(float)
        self.y_user = rng.randint(int(self.en_length / 4), int(3 * self.en_length / 4) + 1, size=self.no_users).astype(float)
        self.z_user = np.zeros(self.no_users)

        # Sinh fading NLoS phức
        self.g_nlos_users = np.sqrt(0.5) * (rng.randn(self.no_users) + 1j * rng.randn(self.no_users))
        self.g_nlos_bs    = np.sqrt(0.5) * (rng.randn(self.no_bs)    + 1j * rng.randn(self.no_bs))


def repair_position_block(pos_block, sim):
    """Sửa lỗi biên và gia tốc bước bay cho quỹ đạo UAV (hỗ trợ cả 1D và 2D batch)."""
    is_1d = (pos_block.ndim == 1)
    if is_1d:
        pos_block = pos_block[None, :]

    N = pos_block.shape[0]
    n_int = sim.n_internal
    x_int = np.clip(pos_block[:, :n_int].real, sim.x_min, sim.x_max)
    z_int = np.clip(pos_block[:, n_int:].real, sim.z_min, sim.z_max)

    x_traj = np.column_stack([np.full(N, sim.x_start), x_int, np.full(N, sim.x_end)])
    z_traj = np.column_stack([np.full(N, sim.z_start), z_int, np.full(N, sim.z_end)])

    T = sim.num_steps
    for _ in range(3):
        for t in range(1, T - 1):
            lo = np.maximum(sim.x_min, x_traj[:, t - 1] - sim.dx_max)
            hi = np.minimum(sim.x_max, x_traj[:, t - 1] + sim.dx_max)
            x_traj[:, t] = np.clip(x_traj[:, t], lo, hi)
        for t in range(T - 2, 0, -1):
            lo = np.maximum(sim.x_min, x_traj[:, t + 1] - sim.dx_max)
            hi = np.minimum(sim.x_max, x_traj[:, t + 1] + sim.dx_max)
            x_traj[:, t] = np.clip(x_traj[:, t], lo, hi)

    for _ in range(3):
        for t in range(1, T - 1):
            lo = np.maximum(sim.z_min, z_traj[:, t - 1] - sim.dz_max)
            hi = np.minimum(sim.z_max, z_traj[:, t - 1] + sim.dz_max)
            z_traj[:, t] = np.clip(z_traj[:, t], lo, hi)
        for t in range(T - 2, 0, -1):
            lo = np.maximum(sim.z_min, z_traj[:, t + 1] - sim.dz_max)
            hi = np.minimum(sim.z_max, z_traj[:, t + 1] + sim.dz_max)
            z_traj[:, t] = np.clip(z_traj[:, t], lo, hi)

    res = np.column_stack([x_traj[:, 1:-1], z_traj[:, 1:-1]])
    return res[0] if is_1d else res


def repair_bs_block(bs_block, sim):
    """Sửa lỗi biên cho vị trí các trạm BS (hỗ trợ cả 1D và 2D batch)."""
    is_1d = (bs_block.ndim == 1)
    if is_1d:
        bs_block = bs_block[None, :]
    x_bs = np.clip(bs_block[:, :sim.no_bs].real, sim.x_bs_min, sim.x_bs_max)
    y_bs = np.clip(bs_block[:, sim.no_bs:].real, sim.y_bs_min, sim.y_bs_max)
    res = np.column_stack([x_bs, y_bs])
    return res[0] if is_1d else res


def repair_alpha_block(pow_block, sim):
    """Chuẩn hóa hệ số công suất NOMA alpha tại từng step (hỗ trợ cả 1D và 2D batch)."""
    is_1d = (pow_block.ndim == 1)
    if is_1d:
        pow_block = pow_block[None, :]
    N = pow_block.shape[0]
    T = sim.num_steps
    K = sim.no_users
    raw_p = np.clip(pow_block.real, sim.p_min, sim.p_max)
    raw_p = raw_p.reshape(N, T, K)
    row_sum = np.sum(raw_p, axis=2, keepdims=True)
    row_sum[row_sum <= 0] = 1.0
    raw_p = raw_p / row_sum
    res = raw_p.reshape(N, -1)
    return res[0] if is_1d else res


def evaluate_trajectory(particle, sim):
    """
    Đánh giá Fitness toàn quỹ đạo từ vector hạt 149D:
    particle: [x_internal(19), z_internal(19), alpha(21*5), x_bs(3), y_bs(3)]
    """
    D_pos = sim.d_pos
    D_pow = sim.d_pow
    D_bs  = sim.d_bs
    T = sim.num_steps
    K = sim.no_users
    M = sim.no_bs

    # Giải mã hạt
    x_internal = particle[:sim.n_internal]
    z_internal = particle[sim.n_internal:D_pos]

    x_traj = np.concatenate(([sim.x_start], x_internal, [sim.x_end]))
    y_traj = sim.steps_vec
    z_traj = np.concatenate(([sim.z_start], z_internal, [sim.z_end]))

    raw_alpha = particle[D_pos:D_pos + D_pow].reshape(T, K)
    raw_alpha = np.maximum(raw_alpha, sim.p_min)
    raw_alpha = raw_alpha / np.sum(raw_alpha, axis=1, keepdims=True)

    bs_block = particle[D_pos + D_pow:]
    x_bs_var = bs_block[:M]
    y_bs_var = bs_block[M:]
    z_bs_var = sim.z_bs_init

    # Kiểm tra vi phạm biên
    penalty = 0.0
    if np.any(x_traj < sim.x_min) or np.any(x_traj > sim.x_max):
        penalty += sim.big_penalty
    if np.any(z_traj < sim.z_min) or np.any(z_traj > sim.z_max):
        penalty += sim.big_penalty
    if np.any(np.abs(np.diff(x_traj)) > sim.dx_max + 1e-6):
        penalty += sim.big_penalty
    if np.any(np.abs(np.diff(z_traj)) > sim.dz_max + 1e-6):
        penalty += sim.big_penalty
    if np.any(x_bs_var < sim.x_bs_min) or np.any(x_bs_var > sim.x_bs_max):
        penalty += sim.big_penalty
    if np.any(y_bs_var < sim.y_bs_min) or np.any(y_bs_var > sim.y_bs_max):
        penalty += sim.big_penalty

    # 1. Vectorized Kênh BS -> UAV: shape (T, M)
    dx_bs = x_traj[:, None] - x_bs_var[None, :]
    dy_bs = y_traj[:, None] - y_bs_var[None, :]
    dz_bs = z_bs_var[None, :] - z_traj[:, None]

    g_dist_bs = np.sqrt(dx_bs**2 + dy_bs**2)
    dist_bs = np.sqrt(g_dist_bs**2 + dz_bs**2)
    angle_bs = np.arctan2(np.abs(dz_bs), np.maximum(g_dist_bs, 1e-12)) * (180.0 / np.pi)

    pow_los_bs = sim.b0 * (dist_bs ** (-sim.eta_path))
    k_val_bs = sim.A1 * np.exp(sim.A2 * angle_bs * (np.pi / 180.0))
    g_val_bs = (np.sqrt(k_val_bs / (1.0 + k_val_bs)) * sim.g_los +
                np.sqrt(1.0 / (1.0 + k_val_bs)) * sim.g_nlos_bs[None, :])
    h_bs = np.sqrt(pow_los_bs) * g_val_bs  # (T, M)

    # Công suất thu SWIPT tại UAV: shape (T,)
    pt_vec = sim.phi * sim.eta * sim.P_r * np.sum(np.abs(h_bs)**2, axis=1)

    # 2. Vectorized Kênh UAV -> Users: shape (T, K)
    dx_u = x_traj[:, None] - sim.x_user[None, :]
    dy_u = y_traj[:, None] - sim.y_user[None, :]
    dz_u = z_traj[:, None]

    g_dist_u = np.sqrt(dx_u**2 + dy_u**2)
    dist_u = np.sqrt(g_dist_u**2 + dz_u**2)
    angle_u = np.arctan2(dz_u, np.maximum(g_dist_u, 1e-12)) * (180.0 / np.pi)

    pow_los_u = sim.b0 * (dist_u ** (-sim.eta_path))
    k_val_u = sim.A1 * np.exp(sim.A2 * angle_u * (np.pi / 180.0))
    g_val_u = (np.sqrt(k_val_u / (1.0 + k_val_u)) * sim.g_los +
               np.sqrt(1.0 / (1.0 + k_val_u)) * sim.g_nlos_users[None, :])
    h_users = np.sqrt(pow_los_u) * g_val_u  # (T, K)
    h2 = np.abs(h_users)**2                # (T, K)

    # 3. Vectorized NOMA SIC decoding
    idx_weak_to_strong = np.argsort(h2, axis=1)  # (T, K)
    h2_ord = np.take_along_axis(h2, idx_weak_to_strong, axis=1)

    alpha_ord = np.sort(raw_alpha, axis=1)[:, ::-1]  # (T, K)
    interf = np.cumsum(alpha_ord[:, ::-1], axis=1)[:, ::-1] - alpha_ord  # (T, K)

    # SINR và Achievable Rate
    pt_mat = pt_vec[:, None]
    sinr = (pt_mat * alpha_ord * h2_ord) / (sim.sigma2 + pt_mat * interf * h2_ord)
    rate_ord = sim.B * np.log2(1.0 + sinr)

    # Map rate_ord trở lại thứ tự user ban đầu
    ach_rate = np.zeros((T, K))
    np.put_along_axis(ach_rate, idx_weak_to_strong, rate_ord, axis=1)

    # Đánh giá fitness trên internal steps (bỏ điểm đầu và điểm cuối)
    fit_idx = slice(1, T - 1)
    step_min = np.min(ach_rate, axis=1)
    step_min_fit = step_min[fit_idx]

    min_fit = np.min(step_min_fit)
    mean_fit = np.mean(step_min_fit)

    # Jain fairness index
    rate_fit = ach_rate[fit_idx, :]
    sum_rate = np.sum(rate_fit, axis=1)
    sum_sq_rate = np.sum(rate_fit**2, axis=1)
    jain_step = (sum_rate**2) / (K * sum_sq_rate + 1e-12)
    fair_penalty = sim.lambda_fair * mean_fit * np.mean(1.0 - jain_step)

    # Độ thô ráp quỹ đạo (Roughness norm)
    rough_x = np.sum(np.abs(np.diff(x_traj, n=2))) / (sim.x_max - sim.x_min + 1e-12)
    rough_z = np.sum(np.abs(np.diff(z_traj, n=2))) / (sim.z_max - sim.z_min + 1e-12)
    rough_norm = rough_x + rough_z

    fitness = min_fit + sim.lambda_mean * mean_fit - fair_penalty - penalty

    res = {
        'fitness': fitness,
        'min_fit': min_fit,
        'mean_fit': mean_fit,
        'global_min_rate': np.min(step_min),
        'ach_rate': ach_rate,
        'step_min': step_min,
        'pt_vec': pt_vec,
        'mean_pt': np.mean(pt_vec),
        'penalty': penalty,
        'is_feasible': 1 if penalty == 0.0 else 0,
        'rough_norm': rough_norm,
        'jain_mean': np.mean(jain_step),
        'x_traj': x_traj,
        'y_traj': y_traj,
        'z_traj': z_traj,
        'x_bs': x_bs_var,
        'y_bs': y_bs_var,
        'z_bs': z_bs_var
    }
    return fitness, res
