"""
analyze_results.py: Phân tích thống kê đối sánh 20 runs giữa Standard JointPSO và V8-SNAPSHOT-CCPSO
Tính toán:
- Tỉ lệ thắng (Win Rate)
- Giá trị trung bình (Mean) và độ lệch chuẩn (Std) của Fitness (kbps), minRate (bps), Jain Index
- Tốc độ tăng tốc trung bình (Average Speedup)
- Vẽ biểu đồ đối sánh phân phối (Boxplots) và biểu đồ cột (Bar Charts)
"""

import os
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def analyze_csv(csv_path=None):
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if csv_path is None:
        csv_path = os.path.join(root_dir, 'output', 'csv', 'v8_ccpso_20_runs_python.csv')

    if not os.path.exists(csv_path):
        print(f"Error: {csv_path} does not exist yet.")
        return

    runs = []
    seeds = []
    std_fit = []
    cc_fit = []
    std_min = []
    cc_min = []
    std_jain = []
    cc_jain = []
    std_time = []
    cc_time = []
    speedup = []

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for r in reader:
            if not r.get('run'):
                continue
            runs.append(int(r['run']))
            seeds.append(int(r['seed']))
            std_fit.append(float(r['std_fitness_kbps']))
            cc_fit.append(float(r['ccpso_fitness_kbps']))
            std_min.append(float(r['std_min_rate_bps']))
            cc_min.append(float(r['ccpso_min_rate_bps']))
            std_jain.append(float(r['std_jain_mean']))
            cc_jain.append(float(r['ccpso_jain_mean']))
            std_time.append(float(r['std_time_s']))
            cc_time.append(float(r['ccpso_time_s']))
            speedup.append(float(r['speedup_factor'].replace('x', '')))

    n_runs = len(runs)
    if n_runs == 0:
        print("No data rows found.")
        return

    std_fit = np.array(std_fit)
    cc_fit = np.array(cc_fit)
    std_min = np.array(std_min)
    cc_min = np.array(cc_min)
    std_jain = np.array(std_jain)
    cc_jain = np.array(cc_jain)
    speedup = np.array(speedup)

    wins = np.sum(cc_fit > std_fit)
    win_rate = (wins / n_runs) * 100

    fit_gain = (cc_fit - std_fit) / std_fit * 100
    min_gain = (cc_min - std_min) / np.maximum(std_min, 1e-6) * 100

    print("=" * 70)
    print(f"       THỐNG KÊ KẾT QUẢ BENCHMARK ({n_runs} RUNS ĐÃ HOÀN TẤT)")
    print("=" * 70)
    print(f"1. TỈ LỆ THẮNG (CC-JointPSO > Standard PSO): {wins}/{n_runs} ({win_rate:.1f}%)")
    print("-" * 70)
    print(f"2. FITNESS (THROUGHPUT - kbps):")
    print(f"   - Standard JointPSO: {np.mean(std_fit):.2f} ± {np.std(std_fit):.2f} kbps [Min: {np.min(std_fit):.2f}, Max: {np.max(std_fit):.2f}]")
    print(f"   - CC-JointPSO:       {np.mean(cc_fit):.2f} ± {np.std(cc_fit):.2f} kbps [Min: {np.min(cc_fit):.2f}, Max: {np.max(cc_fit):.2f}]")
    print(f"   - Mức cải thiện TB:  {np.mean(fit_gain):+.2f}%")
    print("-" * 70)
    print(f"3. GLOBAL MIN-RATE (WORST-USER RATE - bps):")
    print(f"   - Standard JointPSO: {np.mean(std_min):.2f} ± {np.std(std_min):.2f} bps")
    print(f"   - CC-JointPSO:       {np.mean(cc_min):.2f} ± {np.std(cc_min):.2f} bps")
    print(f"   - Mức cải thiện TB:  {np.mean(min_gain):+.2f}%")
    print("-" * 70)
    print(f"4. JAIN'S FAIRNESS INDEX:")
    print(f"   - Standard JointPSO: {np.mean(std_jain):.4f} ± {np.std(std_jain):.4f}")
    print(f"   - CC-JointPSO:       {np.mean(cc_jain):.4f} ± {np.std(cc_jain):.4f}")
    print("-" * 70)
    print(f"5. THỜI GIAN THỰC THI & TỐC ĐỘ (EXECUTION TIME & SPEEDUP):")
    print(f"   - Standard JointPSO: {np.mean(std_time):.2f} ± {np.std(std_time):.2f} s")
    print(f"   - CC-JointPSO:       {np.mean(cc_time):.2f} ± {np.std(cc_time):.2f} s")
    print(f"   - Tốc độ tăng tốc:   {np.mean(speedup):.2f}x (nhanh hơn gấp {np.mean(speedup):.1f} lần)")
    print("=" * 70)

    # Vẽ biểu đồ đối sánh
    fig_dir = os.path.join(root_dir, 'assets', 'figures')
    os.makedirs(fig_dir, exist_ok=True)
    out_fig = os.path.join(fig_dir, 'v8_ccpso_20runs_summary.png')

    fig, axes = plt.subplots(1, 3, figsize=(16, 5))

    # 1. Bar comparison per run
    x = np.arange(len(runs))
    w = 0.38
    axes[0].bar(x - w/2, std_fit, width=w, label='Standard JointPSO (149D)', color='#94a3b8', edgecolor='#475569')
    axes[0].bar(x + w/2, cc_fit, width=w, label='CC-JointPSO (V8-SNAPSHOT)', color='#0284c7', edgecolor='#0369a1')
    axes[0].set_xticks(x)
    axes[0].set_xticklabels([f"R{r}" for r in runs], fontsize=8)
    axes[0].set_ylabel('Fitness (kbps)', fontweight='bold')
    axes[0].set_title(f'Fitness per Run ({wins}/{n_runs} Wins)', fontweight='bold')
    axes[0].grid(True, linestyle='--', alpha=0.5, axis='y')
    axes[0].legend(loc='upper left', fontsize=9)

    # 2. Boxplot distribution
    box_data = [std_fit, cc_fit]
    bplot = axes[1].boxplot(box_data, patch_artist=True, tick_labels=['Standard PSO', 'CC-JointPSO'],
                            medianprops=dict(color='black', linewidth=1.5))
    colors = ['#cbd5e1', '#38bdf8']
    for patch, c in zip(bplot['boxes'], colors):
        patch.set_facecolor(c)
    axes[1].set_ylabel('Fitness (kbps)', fontweight='bold')
    axes[1].set_title('Throughput Distribution', fontweight='bold')
    axes[1].grid(True, linestyle='--', alpha=0.5, axis='y')

    # 3. Execution time comparison
    axes[2].bar(['Standard PSO', 'CC-JointPSO'], [np.mean(std_time), np.mean(cc_time)],
                yerr=[np.std(std_time), np.std(cc_time)], capsize=5,
                color=['#f87171', '#34d399'], edgecolor=['#dc2626', '#059669'])
    axes[2].set_ylabel('Average Runtime (seconds)', fontweight='bold')
    axes[2].set_title(f'Convergence Speed ({np.mean(speedup):.2f}x Faster)', fontweight='bold')
    axes[2].grid(True, linestyle='--', alpha=0.5, axis='y')
    for idx, v in enumerate([np.mean(std_time), np.mean(cc_time)]):
        axes[2].text(idx, v / 2, f"{v:.1f} s", ha='center', va='center', fontweight='bold', color='black')

    plt.tight_layout()
    plt.savefig(out_fig, dpi=300)
    plt.close()
    print(f"Biểu đồ phân tích tổng hợp đã lưu tại: {out_fig}")


if __name__ == '__main__':
    analyze_csv()
