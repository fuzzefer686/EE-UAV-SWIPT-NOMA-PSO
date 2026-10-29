from pathlib import Path
from matplotlib.mathtext import math_to_image
from matplotlib.font_manager import FontProperties

target = Path(__file__).parent.parent / 'assets' / 'math'
target.mkdir(parents=True, exist_ok=True)
equations = {
    'bits_energy': (r'D_k=\tau_{\mathrm{DL}}\sum_{n=1}^{20}R_{n,k},\qquad E_{\mathrm{RF}}=\tau_{\mathrm{DL}}\sum_{n=1}^{20}P_n', '#222222'),
    'ee': (r'\mathrm{EE}_{\mathrm{RF}}=\frac{\sum_{k=1}^{5}D_k}{E_{\mathrm{RF}}}=\frac{\sum_{n=1}^{20}\sum_{k=1}^{5}R_{n,k}}{\sum_{n=1}^{20}P_n}\quad[\mathrm{bit/J}]', '#222222'),
    'power': (r'P_n=\frac{E_{\mathrm{H},n}}{\tau_{\mathrm{DL}}}=\phi\eta P_{\mathrm{BS}}H_n\frac{\tau_{\mathrm{UL}}}{\tau_{\mathrm{DL}}}=\phi\eta P_{\mathrm{BS}}H_n', '#222222'),
    'ordering': (r'g_{n,1}\leq\cdots\leq g_{n,5},\quad\alpha_{n,1}\geq\cdots\geq\alpha_{n,5},\quad\sum_{i=1}^{5}\alpha_{n,i}=1', '#222222'),
    'interference': (r'I_{n,i}=\sum_{j=i+1}^{5}\alpha_{n,j},\qquad I_{n,5}=0', '#222222'),
    'sinr': (r'\mathrm{SINR}_{n,i}=\frac{P_n\alpha_{n,i}g_{n,i}}{\sigma^2+P_ng_{n,i}I_{n,i}}', '#222222'),
    'rate': (r'R_{n,i}=B\log_2(1+\mathrm{SINR}_{n,i}),\qquad B=1\ \mathrm{MHz}', '#222222'),
    'tail': (r'c_i=Pg_i/\sigma^2,\qquad S_i=\sum_{j=i}^{5}\alpha_j', '#222222'),
    'sum_rate': (r'\frac{\sum_i R_i}{B}=\log_2(1+c_1)+\sum_{i=2}^{5}\log_2\left(\frac{1+c_iS_i}{1+c_{i-1}S_i}\right)', '#222222'),
    'derivative': (r'\frac{\partial f_i}{\partial S_i}=\frac{c_i-c_{i-1}}{\ln 2\,(1+c_iS_i)(1+c_{i-1}S_i)}\geq0', '#222222'),
    'data_constraint': (r'D_k=0.5\sum_{n=1}^{20}R_{n,k}\geq L,\qquad\forall k\in\{1,\ldots,5\}', '#C00000'),
    'penalty': (r'\mathrm{fitness}=-\sum_{k=1}^{5}\frac{\max(0,L-D_k)}{\max(L,1)}', '#222222'),
}
for name, (formula, color) in equations.items():
    math_to_image('$'+formula+'$', target / (name+'.svg'), prop=FontProperties(size=24), format='svg', color=color)
print(f'{len(equations)} typeset formulas')
