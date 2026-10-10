"""
main_ccpso.py: Script chạy thử nghiệm phiên bản V8-SNAPSHOT-CCPSO bằng Python
So sánh trực tiếp giữa Standard JointPSO (149D) và CC-JointPSO (38D+6D+105D).
Tự động xuất bảng so sánh số liệu và vẽ đồ thị hội tụ.
"""

import time
import os
import matplotlib
matplotlib.use('Agg')  # Chạy headless không cần màn hình hiển thị
import matplotlib.pyplot as plt

from uav_sim import UAVSimConfig, evaluate_trajectory
from optimizers import (
    get_baseline_particle,
    optimize_joint_pso_standard,
    optimize_joint_ccpso,
    polish_alpha
)


def run_single_comparison(main_seed=2026, max_iter=500, run_polish=True):
    print("=" * 65)
    print(f"  V8-SNAPSHOT-CCPSO SIMULATION (Python Environment)")
    print(f"  Random Seed: {main_seed} | Max Iterations: {max_iter}")
    print("=" * 65)

    sim = UAVSimConfig(main_seed=main_seed, no_users=5, no_bs=3)

    # 1. Baseline
    base_particle = get_baseline_particle(sim)
    fit_base, res_base = evaluate_trajectory(base_particle, sim)
    print(f"\n[1] Baseline Straight Path:")
    print(f"    Fitness:        {fit_base:.4e} bps")
    print(f"    Global minRate: {res_base['global_min_rate']:.4e} bps")

    # 2. Standard JointPSO (149D)
    print(f"\n[2] Running Standard JointPSO (149D, 400 particles, {max_iter} iter)...")
    t0 = time.time()
    res_std_raw = optimize_joint_pso_standard(sim, num_particles=400, max_iter=max_iter, verbose=True)
    time_std = time.time() - t0
    print(f"    Standard PSO done in {time_std:.2f} s | Raw Fitness: {res_std_raw['best_fitness']:.4e} bps")

    if run_polish:
        print("    Running alpha polishing on Standard PSO...")
        res_std = polish_alpha(res_std_raw['best_particle'], sim, n_samples=300)
    else:
        res_std = res_std_raw

    # 3. CC-JointPSO (38D + 6D + 105D)
    print(f"\n[3] Running CC-JointPSO (Sub-swarms: 60, 20, 80 particles, {max_iter} iter)...")
    t0 = time.time()
    res_cc_raw = optimize_joint_ccpso(sim, n_pos=60, n_bs=20, n_pow=80, max_iter=max_iter, verbose=True)
    time_cc = time.time() - t0
    print(f"    CC-JointPSO done in {time_cc:.2f} s | Raw Fitness: {res_cc_raw['best_fitness']:.4e} bps")

    if run_polish:
        print("    Running alpha polishing on CC-JointPSO...")
        res_cc = polish_alpha(res_cc_raw['best_particle'], sim, n_samples=300)
    else:
        res_cc = res_cc_raw

    # 4. In bảng so sánh đối kháng
    print("\n" + "=" * 65)
    print("  FINAL RESULT COMPARISON: V8-SNAPSHOT-CCPSO vs STANDARD PSO")
    print("=" * 65)
    print(f"{'Chỉ tiêu':<28} | {'Standard JointPSO':<18} | {'CC-JointPSO':<18} | {'Cải thiện':<10}")
    print("-" * 65)

    delta_fit = (res_cc['best_fitness'] - res_std['best_fitness']) / res_std['best_fitness'] * 100
    delta_min = (res_cc['global_min_rate'] - res_std['global_min_rate']) / res_std['global_min_rate'] * 100
    speedup = time_std / max(time_cc, 1e-6)

    print(f"{'Fitness (kbps)':<28} | {res_std['best_fitness']/1e3:<18.2f} | {res_cc['best_fitness']/1e3:<18.2f} | {delta_fit:+.2f}%")
    print(f"{'Global minRate (bps)':<28} | {res_std['global_min_rate']:<18.2f} | {res_cc['global_min_rate']:<18.2f} | {delta_min:+.2f}%")
    print(f"{'Jain Fairness Mean':<28} | {res_std['jain_mean']:<18.6f} | {res_cc['jain_mean']:<18.6f} |")
    print(f"{'Roughness Norm':<28} | {res_std['rough_norm']:<18.4f} | {res_cc['rough_norm']:<18.4f} |")
    print(f"{'Thời gian chạy (giây)':<28} | {time_std:<18.2f} | {time_cc:<18.2f} | {speedup:.2f}x faster")
    print("=" * 65)

    # 5. Vẽ đồ thị đường cong hội tụ
    out_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'assets', 'figures')
    os.makedirs(out_dir, exist_ok=True)
    chart_path = os.path.join(out_dir, 'v8_ccpso_convergence_python.png')

    plt.figure(figsize=(9, 5), dpi=180)
    plt.plot(res_std_raw['best_history'] / 1e3, 'g-', linewidth=2.0, label='Standard JointPSO (149D)')
    plt.plot(res_cc_raw['best_history'] / 1e3,   'b-', linewidth=2.2, label='CC-JointPSO (38D+6D+105D)')
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.xlabel('Iteration')
    plt.ylabel('Best Fitness (kbps)')
    plt.title(f'Convergence Comparison: Standard vs CC-JointPSO (Seed {main_seed})')
    plt.legend(loc='lower right', frameon=True)
    plt.tight_layout()
    plt.savefig(chart_path)
    plt.close()
    print(f"\nĐã lưu biểu đồ so sánh hội tụ tại:\n  {chart_path}\n")

    return res_std, res_cc


if __name__ == '__main__':
    run_single_comparison(main_seed=2026, max_iter=300)
