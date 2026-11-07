from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyBboxPatch

root = Path(__file__).resolve().parent
plt.rcParams.update({'font.family': 'serif', 'font.size': 9,
                     'mathtext.fontset': 'stix', 'pdf.fonttype': 42})
fig = plt.figure(figsize=(7.05, 2.45), facecolor='white')
ax = fig.add_axes([0.015, 0.04, 0.60, 0.90])
ax.set(xlim=(0, 6), ylim=(0, 4.3))
ax.axis('off')
teal, blue, orange = '#14656D', '#2C4F86', '#B95720'
route = [(1.2, 3.75), (2.8, 2.9), (2.2, 1.5), (3.0, 0.35)]
ax.plot(*zip(*route), color=teal, lw=1.9, marker='o', ms=3.5, zorder=4)
for p, label, offset in [(route[0], r'$\mathbf{q}_1=\mathbf{q}_{\mathrm{S}}$', (-.12,.25)),
                         (route[1], r'$\mathbf{q}_t$', (.18,.18)),
                         (route[2], r'$\mathbf{q}_{t+1}$', (-.75,-.1)),
                         (route[3], r'$\mathbf{q}_T=\mathbf{q}_{\mathrm{E}}$', (.12,-.06))]:
    ax.text(p[0]+offset[0], p[1]+offset[1], label, color=teal, fontsize=10)
bs = [(0.45, 2.9), (5.35, 3.1), (5.35, .75)]
for m, (x,y) in enumerate(bs, 1):
    ax.add_patch(Rectangle((x-.30,y-.28), .60,.56, fc='#F3F6FA', ec=blue,
                           lw=.7, ls=(0,(3,2)), zorder=1))
    ax.plot(x,y, 's', color=blue, ms=5, zorder=4)
    ax.text(x,y+.43, rf'BS {m}', ha='center', color=blue, fontsize=8.5)
    ax.annotate('', xy=route[1], xytext=(x,y),
                arrowprops={'arrowstyle':'->','lw':.9,'color':orange,'linestyle':(0,(4,3))},
                zorder=2)
users = [(1.0, 1.65), (1.15, .85), (3.55, 1.9), (4.3, 1.1), (3.85,.55)]
for n,(x,y) in enumerate(users,1):
    ax.plot(x,y,'o',ms=4,color=blue,zorder=4)
    ax.text(x+.12,y-.06,rf'UE {n}',fontsize=8)
    if n in (1,3,5):
        ax.annotate('',xy=(x,y+.06),xytext=route[1],
                    arrowprops={'arrowstyle':'->','lw':.7,'color':blue,'alpha':.65},zorder=2)
ax.text(0,4.2,'(a) Horizontal geometry; UAV altitude fixed at $H$', fontsize=9.5)
ax.plot([.15,.65],[.02,.02],color=orange,ls=(0,(4,3)),lw=1)
ax.text(.75,.02,'BS reception / energy supply',va='center',fontsize=7.5)
ax.annotate('',xy=(.16,3.82),xytext=(.16,3.35),
            arrowprops={'arrowstyle':'->','lw':.7,'color':'#444444'})
ax.text(.16,3.96,'$y$',ha='center',fontsize=9)

bx = fig.add_axes([.66,.05,.33,.89])
bx.set(xlim=(0,1),ylim=(0,1)); bx.axis('off')
bx.text(0,1.02,'(b) Service and flight sequence',fontsize=9.5)
boxes=[(.67,'Receive and harvest',r'$\tau_{\mathrm{EH}}$', '#F9EEE7'),
       (.38,'NOMA downlink',r'$\tau_{\mathrm{DL}}$', '#EAF0F8'),
       (.09,'Cruise to next waypoint',r'$\ell_t/v_{\mathrm{c}}$', '#E9F3F2')]
for y,title,duration,col in boxes:
    bx.add_patch(FancyBboxPatch((.04,y),.87,.20,boxstyle='round,pad=.012,rounding_size=.02',
                                facecolor=col,edgecolor='#888888',lw=.6))
    bx.text(.475,y+.135,title,ha='center',va='center',fontsize=8.5)
    bx.text(.475,y+.055,duration,ha='center',va='center',fontsize=10)
for y in [.65,.36]:
    bx.annotate('',xy=(.475,y-.045),xytext=(.475,y),
                arrowprops={'arrowstyle':'->','lw':.8,'color':'#444444'})
bx.text(.475,.94,r'Hover at $\mathbf{q}_t$',ha='center',fontsize=9)
bx.text(.475,0,r'Arrive at $\mathbf{q}_{t+1}$',ha='center',fontsize=9)
fig.savefig(root/'Images'/'system_model.pdf',bbox_inches='tight',pad_inches=.03)
fig.savefig(root/'Images'/'system_model.png',dpi=180,bbox_inches='tight',pad_inches=.03)
plt.close(fig)
