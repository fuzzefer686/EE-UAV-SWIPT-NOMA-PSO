"""Rebuild data, figures and editable tables for the V10A/V10B Beamer report.

Run from any directory with Python 3, numpy, matplotlib and h5py.
No MATLAB execution or optimization is performed.
"""
from pathlib import Path
import csv
import hashlib
import json
import shutil
import statistics as st
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DATA = HERE / 'data'
FIG = HERE / 'figures'
TABLES = HERE / 'tables'
for p in (DATA, FIG, TABLES):
    p.mkdir(exist_ok=True)
ALGOS = ['Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO']
FIELDS = dict(zip(ALGOS, ['resBase', 'trajJoint', 'trajFull', 'trajIPSO']))
SEEDS = [2026, 608060, 3486784401]
COLORS = {'Joint PSO': '#7B4F9D', 'Full PSO': '#0072B2', 'Full IPSO': '#D55E00'}
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10,
                     'axes.spines.top': False, 'axes.spines.right': False,
                     'axes.labelcolor': '#263746', 'text.color': '#263746',
                     'pdf.fonttype': 42, 'axes.titlesize': 12,
                     'legend.fontsize': 9, 'savefig.facecolor': 'white'})


def scalar(g, k):
    return float(g[k][()].ravel()[0])


def extract():
    import h5py
    source = ROOT / 'output/v10_campaign_analysis_20261029/analysis_data.json'
    old = json.loads(source.read_text())
    rows, audit, hashes = [], [], {}
    for folder in dict.fromkeys(r['localFolder'] for r in old):
        path = ROOT / folder / 'results.mat'
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        with h5py.File(path) as f:
            d, sim = f['data'], f['data/sim']
            runrows = [r for r in old if r['localFolder'] == folder]
            for r in runrows:
                r = {k: v for k, v in r.items() if k not in ('history', 'feasibleHistory')}
                g = d[FIELDS[r['algorithm']]]
                for target, key in [('ee', 'eeUAV'), ('energyJ', 'totalEnergy'),
                                    ('bits', 'totalBits'), ('distance', 'totalDistance')]:
                    val = scalar(g, key)
                    assert np.isclose(val, r[target], rtol=1e-10, atol=1e-8)
                assert int(scalar(g, 'isFeasible')) == r['feasible']
                assert np.isclose(r['ee'], r['bits']/r['energyJ'], rtol=1e-10)
                assert np.isclose(r['energyJ'], sum(r[k] for k in ('flightEnergy', 'hoverEnergy', 'rfEnergy')), rtol=1e-10)
                for key in ['xTraj', 'yTraj', 'zTraj', 'xBS', 'yBS', 'zBS', 'totalBitsPerUser']:
                    r[key] = g[key][()].ravel().tolist()
                for key in ['xUser', 'yUser', 'zUser', 'xBS_min', 'xBS_max', 'yBS_min', 'yBS_max']:
                    r[key] = sim[key][()].ravel().tolist()
                r['savedL'] = scalar(sim, 'minBitsPerUser')
                r['savedq'] = scalar(sim, 'minBitsPerUserPerSlot')
                r['savedHover'] = scalar(sim, 'hoverTime')
                assert (r['L'], r['slot'], r['hover']) == (r['savedL'], r['savedq'], r['savedHover'])
                xyz = np.column_stack([r[k] for k in ('xTraj', 'yTraj', 'zTraj')])
                assert np.isclose(np.linalg.norm(np.diff(xyz, axis=0), axis=1).sum(), r['distance'])
                assert np.allclose(r['zTraj'], 30)
                r['algorithmSeed'] = int(scalar(d['cfg/random'], 'algorithmSeed'))
                r['numParticles'] = int(scalar(d['cfg/optimizers/joint'], 'numParticles'))
                r['maxIter'] = int(scalar(d['cfg/optimizers/joint'], 'maxIter'))
                audit.append({'folder': folder, 'algorithm': r['algorithm'], 'ee_mat_matches': True,
                              'energy_identity': True, 'distance_identity': True, 'saved_config_matches': True})
                rows.append(r)
    assert len(rows) == 216 and len(hashes) == 54
    (DATA / 'extracted_results.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2))
    (DATA / 'source_checksums.json').write_text(json.dumps(hashes, indent=2))
    write_csv(DATA / 'audit.csv', audit)
    return rows


def write_csv(path, rows):
    with path.open('w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)


if '--extract' in sys.argv or not (DATA / 'extracted_results.json').exists():
    rows = extract()
else:
    rows = json.loads((DATA / 'extracted_results.json').read_text())
unique = {}
for r in rows:
    key = tuple(r[k] for k in ['variant', 'seed', 'L', 'slot', 'hover', 'algorithm'])
    if key in unique:
        for field in ['ee', 'bits', 'energyJ', 'feasible', 'xTraj', 'yTraj', 'xBS', 'yBS']:
            assert np.allclose(unique[key][field], r[field], rtol=1e-10, atol=1e-8)
    unique.setdefault(key, r)
u = list(unique.values())
assert len(u) == 168
assert set(r['algorithmSeed'] for r in u) == {151459287}
assert set(r['maxIter'] for r in u) == {1000}
assert set(r['numParticles'] for r in u) == {120}


def select(v=None, a=None, L=None, q=None, h=None, seed=None):
    vals = dict(variant=v, algorithm=a, L=L, slot=q, hover=h, seed=seed)
    return [r for r in u if all(z is None or r[k] == z for k, z in vals.items())]


def save(fig, stem):
    fig.savefig(FIG / f'{stem}.pdf', bbox_inches='tight', pad_inches=.06)
    fig.savefig(FIG / f'{stem}.png', bbox_inches='tight', dpi=220, pad_inches=.06)
    plt.close(fig)


summary = []
for sweep, values, params in [('L', [1e6, 2e6, 3e6], {'q': 5000, 'h': 1}),
                               ('q', [0, 5000, 10000], {'L': 3e6, 'h': 1}),
                               ('hover', [1, 2, 3], {'L': 3e6, 'q': 5000})]:
    for v in 'AB':
        for val in values:
            for a in ALGOS:
                p = dict(params); p[{'L': 'L', 'q': 'q', 'hover': 'h'}[sweep]] = val
                rr = select(v, a, **p); good = [r['ee'] for r in rr if r['feasible']]
                summary.append({'sweep': sweep, 'variant': v, 'value': val, 'algorithm': a,
                                'n_feasible': len(good), 'n_total': len(rr),
                                'mean_ee': st.mean(good) if good else '',
                                'median_ee': st.median(good) if good else '',
                                'min_ee': min(good) if good else '', 'max_ee': max(good) if good else ''})
write_csv(DATA / 'ee_summary.csv', summary)


def table_file(name, headers, body, spec=None, caption=''):
    spec = spec or 'l' + 'r'*(len(headers)-1)
    text = '\\begin{table}\n\\centering\n\\renewcommand{\\arraystretch}{1.16}\n'
    text += '\\setlength{\\tabcolsep}{5pt}\n\\begin{tabular}{'+spec+'}\n\\toprule\n'
    text += ' & '.join(headers) + ' \\\\\n\\midrule\n'
    text += ''.join(' & '.join(map(str, row))+' \\\\\n' for row in body)
    text += '\\bottomrule\n\\end{tabular}\n'
    if caption: text += '\\caption{'+caption+'}\n'
    text += '\\end{table}\n'
    (TABLES / f'{name}.tex').write_text(text)


def fmt(x):
    return f'{x:,.1f}'.replace(',', r'\,')


for sweep in ['L', 'q', 'hover']:
    body = []
    for v in 'AB':
        vals = [1e6, 2e6, 3e6] if sweep == 'L' else [0, 5000, 10000] if sweep == 'q' else [1, 2, 3]
        for val in vals:
            rr = [r for r in summary if r['sweep'] == sweep and r['variant'] == v and r['value'] == val]
            label = str(int(val/1e6)) if sweep == 'L' else str(int(val/1000)) if sweep == 'q' else str(val)
            cells = ['V10'+v, label]
            for a in ALGOS[1:]:
                s = next(r for r in rr if r['algorithm'] == a)
                cells.append((fmt(s['mean_ee']) if s['n_feasible'] else '--') + f" ({s['n_feasible']}/3)")
            body.append(cells)
    table_file(f'ee_{sweep}', ['Bản', {'L': '$L$ (Mbit)', 'q': '$q$ (kbit)', 'hover': '$h$ (s)'}[sweep], 'JointPSO', 'Full PSO', 'IPSO'], body,
               caption='EE trung bình (bit/J) trên các seed khả thi. Số trong ngoặc: nghiệm khả thi/3.')

    fig, axes = plt.subplots(1, 2, figsize=(11.4, 3.55), sharey=True, constrained_layout=True)
    # Freeze the shared scale only after accounting for BOTH variants and every seed.
    # Otherwise setting a lower limit after A silently clips larger values in B.
    ymax = max(s['max_ee'] for s in summary if s['sweep'] == sweep and s['algorithm'] != 'Baseline' and s['n_feasible'])/1000*1.16
    for v, ax in zip('AB', axes):
        for ia, a in enumerate(ALGOS[1:]):
            ys = []
            for ix, val in enumerate(vals):
                s = next(r for r in summary if r['sweep'] == sweep and r['variant'] == v and r['value'] == val and r['algorithm'] == a)
                ys.append(s['mean_ee']/1000 if s['n_feasible'] else np.nan)
                p = {'q': 5000, 'h': 1} if sweep == 'L' else {'L': 3e6, 'h': 1} if sweep == 'q' else {'L': 3e6, 'q': 5000}
                p[{'L':'L', 'q':'q', 'hover':'h'}[sweep]] = val
                good = [r for r in select(v, a, **p) if r['feasible']]
                for r in good: ax.scatter(ix+(ia-1)*.075, r['ee']/1000, s=18, color=COLORS[a], alpha=.45, zorder=3)
                if good: ax.annotate(f"{len(good)}/3", (ix, ys[-1]), xytext=(0, 7 if ia != 1 else -14), textcoords='offset points', ha='center', fontsize=7, color=COLORS[a])
            ax.plot(range(3), ys, marker=['s','o','D'][ia], color=COLORS[a], lw=1.8, label=a.replace('Full IPSO','IPSO'))
        ax.set_title('V10'+v); ax.set_ylim(0,ymax); ax.grid(axis='y', alpha=.17)
        ax.set_xticks(range(3), [int(z/1e6) for z in vals] if sweep=='L' else [int(z/1000) for z in vals] if sweep=='q' else vals)
        ax.set_xlabel({'L':'L (Mbit/user)', 'q':'q (kbit/user/serving-slot)', 'hover':'Hover (s/serving point)'}[sweep])
    axes[0].set_ylabel('EE (kbit/J)'); axes[0].legend(loc='upper left', frameon=False)
    save(fig, f'ee_{sweep}')

for v in 'AB':
    for sweep in ['L','q']:
        body = []
        for seed in SEEDS:
            for val in ([1e6,2e6,3e6] if sweep=='L' else [0,5000,10000]):
                rr=select(v,L=val if sweep=='L' else 3e6,q=5000 if sweep=='L' else val,h=1,seed=seed)
                cells=[str(seed),str(int(val/(1e6 if sweep=='L' else 1000)))]
                for a in ALGOS[1:]:
                    r=next(r for r in rr if r['algorithm']==a)
                    cells.append(fmt(r['ee'])+('' if r['feasible'] else r'$^{\dagger}$'))
                body.append(cells)
        table_file(f'detail_{sweep}_{v}', ['Seed', '$L$ (Mbit)' if sweep=='L' else '$q$ (kbit)', 'JointPSO','Full PSO','IPSO'],body,
                   caption=r'EE tính được (bit/J). $\dagger$: nghiệm vi phạm ràng buộc, chỉ dùng chẩn đoán.')

fixed_rows=[]
bs_rows=[]
waypoints=[]
for r in u:
    if r['L'] != 3e6: continue
    meta={k:r[k] for k in ['variant','seed','slot','hover','algorithm','feasible','ee','localFolder']}
    for j in range(3):
        bs_rows.append({**meta,'BS':j+1,'x':r['xBS'][j],'y':r['yBS'][j],'z':r['zBS'][j]})
    for j in range(21):
        waypoints.append({**meta,'waypoint':j+1,'x':r['xTraj'][j],'y':r['yTraj'][j],'z':r['zTraj'][j]})
write_csv(DATA/'bs_all_L3.csv',bs_rows)
write_csv(DATA/'waypoints_all_L3.csv',waypoints)
write_csv(DATA/'bs_default_L3_q5_h1.csv',[r for r in bs_rows if r['slot']==5000 and r['hover']==1])

for v in 'AB':
    body=[]
    for seed in SEEDS:
        for a in ALGOS[2:]:
            r=select(v,a,L=3e6,q=5000,h=1,seed=seed)[0]
            body.append([str(seed),'PSO' if a=='Full PSO' else 'IPSO']+[f"({r['xBS'][j]:.2f}, {r['yBS'][j]:.2f})" for j in range(3)])
    table_file(f'bs_default_{v}', ['Seed','Thuật toán','BS1: $(x,y)$','BS2: $(x,y)$','BS3: $(x,y)$'], body, 'llrrr',
               caption=r'Tọa độ theo mét, $z_{\rm BS1}=20$, $z_{\rm BS2}=30$, $z_{\rm BS3}=25$ m. Cả 6 nghiệm đều khả thi.')

    for a in ALGOS[2:]:
        body=[]
        for r in sorted(select(v,a,L=3e6),key=lambda r:(r['seed'],r['hover'],r['slot'])):
            body.append([str(r['seed']),str(int(r['slot']/1000)),str(int(r['hover']))]+[f"({r['xBS'][j]:.2f}, {r['yBS'][j]:.2f})" for j in range(3)]+['OK' if r['feasible'] else r'$\dagger$'])
        table_file(f'bs_all_{v}_{a.replace(" ", "_")}', ['Seed','$q$','$h$','BS1 $(x,y)$','BS2 $(x,y)$','BS3 $(x,y)$','Đạt'],body,'rrrcccr',
                   caption=r'$L=3$ Mbit/user. $q$: kbit/user/slot, $h$: s. Độ cao BS1/2/3: 20/30/25 m. Tọa độ làm tròn 0,01 m.')

for v in 'AB':
    for seed in SEEDS:
        fig,axes=plt.subplots(1,3,figsize=(12.3,4.0),sharex=True,sharey=True,layout='constrained')
        for ax,a in zip(axes,ALGOS[1:]):
            r=select(v,a,L=3e6,q=5000,h=1,seed=seed)[0]
            for j in range(3):
                ax.add_patch(Rectangle((r['xBS_min'][j],r['yBS_min'][j]),r['xBS_max'][j]-r['xBS_min'][j],r['yBS_max'][j]-r['yBS_min'][j],facecolor='#DFEAF2',edgecolor='#95AEC1',lw=.7,zorder=0))
            ax.axvspan(75,225,color='#E8F3EF',alpha=.5,zorder=-1)
            ax.plot([150,150],[300,0],color='#AAB2BA',ls=':',lw=1)
            ax.plot(r['xTraj'],r['yTraj'],color=COLORS[a],marker='o',ms=3,lw=1.7,ls='-' if r['feasible'] else '--',zorder=4,label='UAV')
            ax.scatter(r['xUser'],r['yUser'],marker='*',s=100,c='#CC3344',edgecolors='white',linewidths=.5,zorder=5,label='User')
            for j,(xx,yy) in enumerate(zip(r['xUser'],r['yUser'])):ax.annotate(f'U{j+1}',(xx,yy),xytext=(4,4),textcoords='offset points',fontsize=8,color='#A32D3D')
            ax.scatter(r['xBS'],r['yBS'],marker='^',s=90,c='#253F51',edgecolors='white',linewidths=.6,zorder=6,label='BS')
            for j,(xx,yy) in enumerate(zip(r['xBS'],r['yBS'])):ax.annotate(f'B{j+1}',(xx,yy),xytext=(-5,-13),textcoords='offset points',fontsize=8,ha='center')
            ax.scatter([150],[300],marker='s',s=40,c='#15806B',zorder=7)
            ax.scatter([150],[0],marker='X',s=52,c='#111111',zorder=7)
            ax.annotate('S',(150,300),xytext=(5,1),textcoords='offset points',fontsize=8)
            ax.annotate('E',(150,0),xytext=(5,2),textcoords='offset points',fontsize=8)
            ax.set_title(a.replace('Full IPSO','IPSO')+f"\nEE={r['ee']:,.1f} bit/J; "+('OK' if r['feasible'] else 'INFEASIBLE'),fontsize=10)
            ax.set_aspect('equal');ax.set_xlim(-16,318);ax.set_ylim(-16,318)
            ax.set_xticks([0,75,150,225,300]);ax.set_yticks([0,75,150,225,300]);ax.tick_params(labelsize=8)
            ax.grid(alpha=.16);ax.set_xlabel('X (m)')
        axes[0].set_ylabel('Y (m)')
        save(fig,f'trajectory_{v}_{seed}')

# L=3 Mbit, all five distinct (q,hover) settings and both BS-optimizing methods.
opts=[r for r in u if r['L']==3e6 and r['algorithm'] in ALGOS[2:]]
fig,axes=plt.subplots(1,3,figsize=(11.8,3.8),layout='constrained')
for j,ax in enumerate(axes):
    bounds=[(250,300,250,300),(0,50,100,200),(250,300,0,50)][j]
    ax.add_patch(Rectangle((bounds[0],bounds[2]),bounds[1]-bounds[0],bounds[3]-bounds[2],facecolor='#EDF3F7',edgecolor='#7795AA',lw=1))
    for v,c,dx in [('A','#0072B2',-.5),('B','#D55E00',.5)]:
        for a,m in [('Full PSO','o'),('Full IPSO','x')]:
            rr=[r for r in opts if r['variant']==v and r['algorithm']==a]
            # Jitter is deliberately avoided: plotted positions are the actual coordinates.
            ax.scatter([r['xBS'][j] for r in rr],[r['yBS'][j] for r in rr],c=c,marker=m,s=32,alpha=.62,label=v+' '+a.replace('Full ',''),zorder=3)
    ax.set_xlim(bounds[0]-4,bounds[1]+4);ax.set_ylim(bounds[2]-5,bounds[3]+5)
    ax.set_xlabel('X (m)');ax.set_ylabel('Y (m)');ax.set_title(f'BS{j+1}');ax.grid(alpha=.15)
axes[1].legend(fontsize=8,frameon=True,loc='center right')
save(fig,'bs_distribution_L3')

stats={}
for title,rr in [('default',[r for r in opts if r['slot']==5000 and r['hover']==1]),('all_L3',opts),('feasible_L3',[r for r in opts if r['feasible']])]:
    stats[title]={'n':len(rr)}
    for name,j,axis,val in [('x1_250',0,'xBS',250),('x2_50',1,'xBS',50),('x3_250',2,'xBS',250),('y3_50',2,'yBS',50)]:
        stats[title][name]=sum(abs(r[axis][j]-val)<=1e-3 for r in rr)
    stats[title]['bs3_250_50']=sum(abs(r['xBS'][2]-250)<=1e-3 and abs(r['yBS'][2]-50)<=1e-3 for r in rr)
(DATA/'bs_boundary_summary.json').write_text(json.dumps(stats,indent=2))

paired=[]
for a in ALGOS[1:]:
    for ra in select('A',a):
        rb=select('B',a,L=ra['L'],q=ra['slot'],h=ra['hover'],seed=ra['seed'])[0]
        if ra['feasible'] and rb['feasible']:paired.append({'algorithm':a,'seed':ra['seed'],'L':ra['L'],'q':ra['slot'],'hover':ra['hover'],'A_ee':ra['ee'],'B_ee':rb['ee'],'gain_percent':100*(rb['ee']/ra['ee']-1)})
write_csv(DATA/'paired_A_B.csv',paired)
print(json.dumps({'rows':len(rows),'unique_rows':len(u),'bs_stats':stats,'IPSO_A_B_gain':st.mean(r['gain_percent'] for r in paired if r['algorithm']=='Full IPSO')},indent=2))

