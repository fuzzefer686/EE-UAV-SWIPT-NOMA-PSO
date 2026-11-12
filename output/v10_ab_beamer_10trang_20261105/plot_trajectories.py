"""Rebuild the two trajectory figures from the attached exported results."""
from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

P = Path(__file__).resolve().parent
rows = json.loads((P/'data/extracted_results.json').read_text())
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42,
                     'axes.spines.top':False,'axes.spines.right':False})
for seed in [2026,3486784401]:
    fig,axes=plt.subplots(1,2,figsize=(10.7,4.15),sharex=True,sharey=True,layout='constrained')
    for v,c,ax in zip('AB',['#0072B2','#D55E00'],axes):
        r=next(r for r in rows if r['variant']==v and r['seed']==seed and r['algorithm']=='Full IPSO' and r['L']==3e6 and r['slot']==5000 and r['hover']==1)
        for j in range(3):
            ax.add_patch(Rectangle((r['xBS_min'][j],r['yBS_min'][j]),r['xBS_max'][j]-r['xBS_min'][j],r['yBS_max'][j]-r['yBS_min'][j],facecolor='#E5EFF5',edgecolor='#9BB0C2',lw=.7,zorder=0))
        ax.axvspan(75,225,color='#EBF4EF',alpha=.55,zorder=-1)
        ax.plot(r['xTraj'],r['yTraj'],color=c,lw=1.8,marker='o',ms=3.8,zorder=3)
        ax.scatter(r['xUser'],r['yUser'],c='#C73546',marker='*',s=115,edgecolors='white',linewidths=.6,zorder=5)
        for j,(x,y) in enumerate(zip(r['xUser'],r['yUser'])):
            ax.annotate(f'U{j+1}',(x,y),xytext=(4,5),textcoords='offset points',fontsize=9,color='#AD2D3D')
        ax.scatter(r['xBS'],r['yBS'],marker='^',s=95,c='#244054',edgecolors='white',linewidths=.5,zorder=6)
        for j,(x,y) in enumerate(zip(r['xBS'],r['yBS'])):
            ax.annotate(f'BS{j+1}',(x,y),xytext=(0,-14),textcoords='offset points',ha='center',fontsize=9)
        ax.scatter([150],[300],s=43,marker='s',c='#147F67',zorder=7)
        ax.scatter([150],[0],s=55,marker='X',c='black',zorder=7)
        ax.annotate('S',(150,300),xytext=(5,2),textcoords='offset points',fontsize=9)
        ax.annotate('E',(150,0),xytext=(5,2),textcoords='offset points',fontsize=9)
        ax.set_title(f"V10{v} + IPSO: {r['ee']:,.1f} bit/J\nD = {r['distance']:.1f} m",fontsize=11)
        ax.set_xlim(-15,318);ax.set_ylim(-18,318);ax.set_aspect('equal')
        ax.set_xticks([0,75,150,225,300]);ax.set_yticks([0,75,150,225,300]);ax.grid(alpha=.16)
        ax.set_xlabel('X (m)')
    axes[0].set_ylabel('Y (m)')
    for ext in ['pdf','png']:fig.savefig(P/f'figures/trajectory_{seed}.{ext}',bbox_inches='tight',pad_inches=.06,dpi=220)
    plt.close(fig)
