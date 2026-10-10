"""
optimizers.py: Các thuật toán tối ưu hóa bầy đàn cho UAV SWIPT-NOMA
1. Standard JointPSO (149 chiều - V8 gốc)
2. CC-JointPSO (Cooperative Co-evolutionary 3 phân đàn - V8-SNAPSHOT-CCPSO)
3. Alpha Polishing (Tinh chỉnh công suất NOMA)
"""

import numpy as np
from uav_sim import (
    repair_position_block,
    repair_bs_block,
    repair_alpha_block,
    evaluate_trajectory
)


def repair_full_particle(particles, sim):
    """Sửa lỗi toàn bộ hạt 149 chiều (hỗ trợ cả 1D và 2D batch)."""
    is_1d = (particles.ndim == 1)
    if is_1d:
        particles = particles[None, :]
    D_pos = sim.d_pos
    D_pow = sim.d_pow
    pos_b = repair_position_block(particles[:, :D_pos], sim)
    pow_b = repair_alpha_block(particles[:, D_pos:D_pos + D_pow], sim)
    bs_b  = repair_bs_block(particles[:, D_pos + D_pow:], sim)
    res = np.column_stack([pos_b, pow_b, bs_b])
    return res[0] if is_1d else res


def polish_traj(particle, sim, n_rounds=2):
    """
    Trajectory Polishing: Tinh chỉnh tọa độ X và Z các waypoint nội bộ
    bằng Coordinate Descent đa bước [8.0, 4.0, 2.0] mét.
    """
    p = particle.copy()
    fit_best, res_best = evaluate_trajectory(p, sim)
    idx_pos = slice(0, sim.d_pos)
    pos_cur = p[idx_pos].copy()

    for _ in range(n_rounds):
        for step_size in [8.0, 4.0, 2.0]:
            for dim in range(sim.d_pos):
                for delta in [-step_size, step_size]:
                    pos_test = pos_cur.copy()
                    pos_test[dim] += delta
                    pos_test = repair_position_block(pos_test, sim)
                    p_test = p.copy()
                    p_test[idx_pos] = pos_test
                    fit_t, res_t = evaluate_trajectory(p_test, sim)
                    if fit_t > fit_best:
                        fit_best = fit_t
                        res_best = res_t
                        pos_cur = pos_test.copy()
                        p = p_test.copy()
    return p, fit_best, res_best


def polish_bs(particle, sim, n_steps=2):
    """
    BS Polishing: Tinh chỉnh cục bộ 6 tọa độ trạm BS để tối đa hóa công suất thu SWIPT.
    Sử dụng Coordinate Descent với bước nhảy suy giảm [10.0, 5.0, 2.0] mét.
    """
    D_pos = sim.d_pos
    D_pow = sim.d_pow
    p = particle.copy()
    fit_best, res_best = evaluate_trajectory(p, sim)
    idx_bs = slice(D_pos + D_pow, len(p))
    bs_cur = p[idx_bs].copy()

    for _ in range(n_steps):
        for step_size in [10.0, 5.0, 2.0]:
            for dim in range(len(bs_cur)):
                for delta in [-step_size, step_size]:
                    bs_test = bs_cur.copy()
                    bs_test[dim] += delta
                    bs_test = repair_bs_block(bs_test, sim)
                    p_test = p.copy()
                    p_test[idx_bs] = bs_test
                    fit_t, res_t = evaluate_trajectory(p_test, sim)
                    if fit_t > fit_best:
                        fit_best = fit_t
                        res_best = res_t
                        bs_cur = bs_test.copy()
                        p = p_test.copy()
    return p, fit_best, res_best


def get_baseline_particle(sim):
    """Sinh hạt cơ sở (đường bay thẳng, alpha đều, BS ban đầu)."""
    T = sim.num_steps
    x_base = np.linspace(sim.x_start, sim.x_end, T)
    z_base = np.linspace(sim.z_start, sim.z_end, T)
    alpha_base = np.ones((T, sim.no_users)) / sim.no_users

    base_pos = np.concatenate((x_base[1:-1], z_base[1:-1]))
    base_pow = alpha_base.flatten()
    base_bs  = np.concatenate((sim.x_bs_init, sim.y_bs_init))
    return np.concatenate((base_pos, base_pow, base_bs))


def optimize_joint_pso_standard(sim, num_particles=400, max_iter=1000,
                                w=0.7, c1=1.5, c2=1.5, seed=151459287, verbose=True):
    """
    Standard JointPSO 149 chiều (Thuật toán của V8 gốc).
    """
    rng = np.random.RandomState(seed)
    D = sim.D

    particles_pos = np.zeros((num_particles, D))
    particles_vel = np.zeros((num_particles, D))
    pbest_pos = np.zeros((num_particles, D))
    pbest_val = -np.inf * np.ones(num_particles)

    gbest_val = -np.inf
    gbest_pos = np.zeros(D)
    gbest_res = None
    best_history = np.zeros(max_iter + 1)

    base_particle = get_baseline_particle(sim)

    # Khởi tạo bầy đàn
    for i in range(num_particles):
        if i == 0:
            particles_pos[i, :] = base_particle
        else:
            # Random position
            n_int = sim.n_internal
            x_rand = sim.x_min + rng.rand(n_int) * (sim.x_max - sim.x_min)
            z_rand = sim.z_min + rng.rand(n_int) * (sim.z_max - sim.z_min)
            # Random alpha
            pow_rand = sim.p_min + rng.rand(sim.d_pow) * (sim.p_max - sim.p_min)
            # Random BS
            bs_x_rand = sim.x_bs_min + rng.rand(sim.no_bs) * (sim.x_bs_max - sim.x_bs_min)
            bs_y_rand = sim.y_bs_min + rng.rand(sim.no_bs) * (sim.y_bs_max - sim.y_bs_min)

            particles_pos[i, :] = np.concatenate((x_rand, z_rand, pow_rand, bs_x_rand, bs_y_rand))

        particles_pos[i, :] = repair_full_particle(particles_pos[i, :], sim)
        fit_i, res_i = evaluate_trajectory(particles_pos[i, :], sim)

        pbest_pos[i, :] = particles_pos[i, :].copy()
        pbest_val[i] = fit_i

        if fit_i > gbest_val:
            gbest_val = fit_i
            gbest_pos = particles_pos[i, :].copy()
            gbest_res = res_i

    best_history[0] = gbest_val

    # Vòng lặp PSO chính
    for it in range(1, max_iter + 1):
        r1 = rng.rand(num_particles, D)
        r2 = rng.rand(num_particles, D)

        particles_vel = (w * particles_vel
                         + c1 * r1 * (pbest_pos - particles_pos)
                         + c2 * r2 * (gbest_pos - particles_pos))
        particles_pos = particles_pos + particles_vel

        particles_pos = repair_full_particle(particles_pos, sim)
        for i in range(num_particles):
            fit_i, res_i = evaluate_trajectory(particles_pos[i, :], sim)

            if fit_i > pbest_val[i]:
                pbest_val[i] = fit_i
                pbest_pos[i, :] = particles_pos[i, :].copy()

            if fit_i > gbest_val:
                gbest_val = fit_i
                gbest_pos = particles_pos[i, :].copy()
                gbest_res = res_i

        best_history[it] = gbest_val
        if verbose and (it % 100 == 0 or it == 1 or it == max_iter):
            print(f"  [Standard PSO] Iter {it:4d}/{max_iter:4d} | Best Fitness: {gbest_val:.4e} bps")

    out = gbest_res.copy()
    out['best_particle'] = gbest_pos
    out['best_fitness'] = gbest_val
    out['best_history'] = best_history
    return out


def optimize_joint_ccpso(sim, n_pos=100, n_bs=30, n_pow=80, max_iter=350,
                         w=0.7, c1=1.5, c2=1.5, seed=151459287, verbose=True, run_polish=True):
    """
    Cooperative Co-evolutionary JointPSO (CC-JointPSO - V8-SNAPSHOT-CCPSO Top).
    Phân tách 149D thành 3 phân đàn con: Quỹ đạo (38D), BS (6D), Alpha (105D).
    Tích hợp khởi tạo 4-hành lang, giới hạn vận tốc đa chiều và quy trình Three-Stage Polish.
    """
    rng = np.random.RandomState(seed)

    D_pos = sim.d_pos  # 38
    D_bs  = sim.d_bs   # 6
    D_pow = sim.d_pow  # 105
    n_int = sim.n_internal

    base_p = get_baseline_particle(sim)
    context_pos = base_p[:D_pos].copy()
    context_pow = base_p[D_pos:D_pos + D_pow].copy()
    context_bs  = base_p[D_pos + D_pow:].copy()

    # Đánh giá ban đầu cho Context Vector
    gbest_val, gbest_res = evaluate_trajectory(base_p, sim)
    gbest_pos = context_pos.copy()
    gbest_pow = context_pow.copy()
    gbest_bs  = context_bs.copy()

    # Giới hạn vận tốc theo đặc thù từng chiều không gian
    v_max_pos = np.concatenate([np.full(n_int, 0.20 * (sim.x_max - sim.x_min)),
                                np.full(n_int, 0.15 * (sim.z_max - sim.z_min))])
    v_max_bs  = 0.20 * sim.bs_margin
    v_max_pow = 0.15

    # 1. Khởi tạo Sub-swarm 1: Trajectory với 4 hành lang cấu trúc
    swarm_pos = np.zeros((n_pos, D_pos))
    vel_pos   = np.zeros((n_pos, D_pos))
    pbest_pos = np.zeros((n_pos, D_pos))
    pbest_val_pos = -np.inf * np.ones(n_pos)

    u_mean_x = np.mean(sim.x_user)

    for i in range(n_pos):
        if i == 0:
            swarm_pos[i, :] = context_pos
        elif i < n_pos // 4:
            # Hành lang 1: Hướng về trọng tâm User
            x_c = np.linspace(sim.x_start, u_mean_x, sim.num_steps)[1:-1] + rng.randn(n_int) * 8
            z_c = np.full(n_int, 18.0) + rng.rand(n_int) * 4
            swarm_pos[i, :] = np.concatenate((x_c, z_c))
        elif i < 2 * n_pos // 4:
            # Hành lang 2: Bay sát sườn Đông quét BS 1 và BS 3 (SWIPT cực đại)
            x_c = np.full(n_int, 210.0) + rng.randn(n_int) * 10
            z_c = np.full(n_int, 16.0) + rng.rand(n_int) * 3
            swarm_pos[i, :] = np.concatenate((x_c, z_c))
        elif i < 3 * n_pos // 4:
            # Hành lang 3: Đường bay trực diện độ cao thấp
            x_c = np.linspace(sim.x_start, sim.x_end, sim.num_steps)[1:-1] + rng.randn(n_int) * 10
            z_c = np.full(n_int, sim.z_min + 1.0) + rng.rand(n_int) * 4
            swarm_pos[i, :] = np.concatenate((x_c, z_c))
        else:
            # Hành lang 4: Thăm dò ngẫu nhiên toàn không gian
            x_rand = sim.x_min + rng.rand(n_int) * (sim.x_max - sim.x_min)
            z_rand = sim.z_min + rng.rand(n_int) * (sim.z_max - sim.z_min)
            swarm_pos[i, :] = np.concatenate((x_rand, z_rand))

    swarm_pos = repair_position_block(swarm_pos, sim)
    for i in range(n_pos):
        cand = np.concatenate((swarm_pos[i, :], gbest_pow, gbest_bs))
        fit, res = evaluate_trajectory(cand, sim)

        pbest_pos[i, :] = swarm_pos[i, :].copy()
        pbest_val_pos[i] = fit
        if fit > gbest_val:
            gbest_val = fit
            gbest_pos = swarm_pos[i, :].copy()
            gbest_res = res
    context_pos = gbest_pos.copy()

    # 2. Khởi tạo Sub-swarm 2: BS Placement (6D)
    swarm_bs = np.zeros((n_bs, D_bs))
    vel_bs   = np.zeros((n_bs, D_bs))
    pbest_bs = np.zeros((n_bs, D_bs))
    pbest_val_bs = -np.inf * np.ones(n_bs)

    for i in range(n_bs):
        if i == 0:
            swarm_bs[i, :] = context_bs
        else:
            x_b = sim.x_bs_min + rng.rand(sim.no_bs) * (sim.x_bs_max - sim.x_bs_min)
            y_b = sim.y_bs_min + rng.rand(sim.no_bs) * (sim.y_bs_max - sim.y_bs_min)
            swarm_bs[i, :] = np.concatenate((x_b, y_b))

        swarm_bs[i, :] = repair_bs_block(swarm_bs[i, :], sim)
        cand = np.concatenate((gbest_pos, gbest_pow, swarm_bs[i, :]))
        fit, res = evaluate_trajectory(cand, sim)

        pbest_bs[i, :] = swarm_bs[i, :].copy()
        pbest_val_bs[i] = fit
        if fit > gbest_val:
            gbest_val = fit
            gbest_bs = swarm_bs[i, :].copy()
            gbest_res = res
    context_bs = gbest_bs.copy()

    # 3. Khởi tạo Sub-swarm 3: Power Allocation (105D)
    swarm_pow = np.zeros((n_pow, D_pow))
    vel_pow   = np.zeros((n_pow, D_pow))
    pbest_pow = np.zeros((n_pow, D_pow))
    pbest_val_pow = -np.inf * np.ones(n_pow)

    for i in range(n_pow):
        if i == 0:
            swarm_pow[i, :] = context_pow
        else:
            swarm_pow[i, :] = sim.p_min + rng.rand(D_pow) * (sim.p_max - sim.p_min)

        swarm_pow[i, :] = repair_alpha_block(swarm_pow[i, :], sim)
        cand = np.concatenate((gbest_pos, swarm_pow[i, :], gbest_bs))
        fit, res = evaluate_trajectory(cand, sim)

        pbest_pow[i, :] = swarm_pow[i, :].copy()
        pbest_val_pow[i] = fit
        if fit > gbest_val:
            gbest_val = fit
            gbest_pow = swarm_pow[i, :].copy()
            gbest_res = res
    context_pow = gbest_pow.copy()

    best_history = np.zeros(max_iter + 1)
    best_history[0] = gbest_val

    # VÒNG LẶP TIẾN HÓA HỢP TÁC CC-PSO (Round-Robin)
    for it in range(1, max_iter + 1):

        # LƯỢT 1: Quỹ đạo UAV (38D)
        r1 = rng.rand(n_pos, D_pos)
        r2 = rng.rand(n_pos, D_pos)
        vel_pos = w * vel_pos + c1 * r1 * (pbest_pos - swarm_pos) + c2 * r2 * (gbest_pos - swarm_pos)
        vel_pos = np.clip(vel_pos, -v_max_pos, v_max_pos)
        swarm_pos = swarm_pos + vel_pos
        swarm_pos = repair_position_block(swarm_pos, sim)

        for i in range(n_pos):
            cand = np.concatenate((swarm_pos[i, :], context_pow, context_bs))
            fit, res = evaluate_trajectory(cand, sim)

            if fit > pbest_val_pos[i]:
                pbest_val_pos[i] = fit
                pbest_pos[i, :] = swarm_pos[i, :].copy()
            if fit > gbest_val:
                gbest_val = fit
                gbest_pos = swarm_pos[i, :].copy()
                gbest_res = res
        context_pos = gbest_pos.copy()

        # LƯỢT 2: Trạm BS (6D)
        r1 = rng.rand(n_bs, D_bs)
        r2 = rng.rand(n_bs, D_bs)
        vel_bs = w * vel_bs + c1 * r1 * (pbest_bs - swarm_bs) + c2 * r2 * (gbest_bs - swarm_bs)
        vel_bs = np.clip(vel_bs, -v_max_bs, v_max_bs)
        swarm_bs = swarm_bs + vel_bs
        swarm_bs = repair_bs_block(swarm_bs, sim)

        for i in range(n_bs):
            cand = np.concatenate((context_pos, context_pow, swarm_bs[i, :]))
            fit, res = evaluate_trajectory(cand, sim)

            if fit > pbest_val_bs[i]:
                pbest_val_bs[i] = fit
                pbest_bs[i, :] = swarm_bs[i, :].copy()
            if fit > gbest_val:
                gbest_val = fit
                gbest_bs = swarm_bs[i, :].copy()
                gbest_res = res
        context_bs = gbest_bs.copy()

        # LƯỢT 3: Công suất NOMA (105D)
        r1 = rng.rand(n_pow, D_pow)
        r2 = rng.rand(n_pow, D_pow)
        vel_pow = w * vel_pow + c1 * r1 * (pbest_pow - swarm_pow) + c2 * r2 * (gbest_pow - swarm_pow)
        vel_pow = np.clip(vel_pow, -v_max_pow, v_max_pow)
        swarm_pow = swarm_pow + vel_pow
        swarm_pow = repair_alpha_block(swarm_pow, sim)

        for i in range(n_pow):
            cand = np.concatenate((context_pos, swarm_pow[i, :], context_bs))
            fit, res = evaluate_trajectory(cand, sim)

            if fit > pbest_val_pow[i]:
                pbest_val_pow[i] = fit
                pbest_pow[i, :] = swarm_pow[i, :].copy()
            if fit > gbest_val:
                gbest_val = fit
                gbest_pow = swarm_pow[i, :].copy()
                gbest_res = res
        context_pow = gbest_pow.copy()

        best_history[it] = gbest_val
        if verbose and (it % 100 == 0 or it == 1 or it == max_iter):
            print(f"  [CC-JointPSO]  Iter {it:4d}/{max_iter:4d} | Best Fitness: {gbest_val:.4e} bps")

    # Three-Stage Polish: Trajectory Polish -> BS Polish -> Alpha Polish
    full_best = np.concatenate((gbest_pos, gbest_pow, gbest_bs))
    if run_polish:
        p_pol, f_pol, r_pol = polish_traj(full_best, sim, n_rounds=2)
        p_pol, f_pol, r_pol = polish_bs(p_pol, sim, n_steps=2)
        out = polish_alpha(p_pol, sim, n_samples=300)
    else:
        fit_f, res_f = evaluate_trajectory(full_best, sim)
        out = res_f.copy()
        out['best_particle'] = full_best
        out['best_fitness'] = fit_f

    out['best_history'] = best_history
    return out


def polish_alpha(particle, sim, n_samples=500, seed=152459287):
    """
    Alpha polishing: giữ nguyên Quỹ đạo và BS, tinh chỉnh lại alpha tại từng step.
    """
    rng = np.random.RandomState(seed)
    T = sim.num_steps
    K = sim.no_users
    D_pos = sim.d_pos

    p = particle.copy()
    fit_cur, res_cur = evaluate_trajectory(p, sim)

    # Chỉ tinh chỉnh các step nội bộ
    for t in range(1, T - 1):
        idx_alpha = slice(D_pos + t * K, D_pos + (t + 1) * K)

        best_local_p = p.copy()
        best_local_fit = fit_cur

        for s in range(n_samples):
            if s == 0:
                alpha = np.ones(K) / K
            elif s == 1:
                alpha = p[idx_alpha]
                alpha = np.maximum(alpha, sim.p_min)
                alpha /= np.sum(alpha)
            else:
                alpha = rng.rand(K)
                alpha = np.maximum(alpha, sim.p_min)
                alpha /= np.sum(alpha)

            p_test = p.copy()
            p_test[idx_alpha] = alpha
            fit_test, _ = evaluate_trajectory(p_test, sim)

            if fit_test > best_local_fit:
                best_local_fit = fit_test
                best_local_p = p_test.copy()

        p = best_local_p.copy()
        fit_cur = best_local_fit

    final_fit, final_res = evaluate_trajectory(p, sim)
    final_res['best_particle'] = p
    final_res['best_fitness'] = final_fit
    return final_res
