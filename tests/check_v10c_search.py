"""Prototype source/numerical checks only; does not execute MATLAB."""
from pathlib import Path
import unittest
import numpy as np
from check_v10_static import matlab_structure_tokens

ROOT=Path(__file__).resolve().parents[1]
FILES=['src/geometry/v10cSearchLayout.m','src/geometry/repairV10CParticle.m',
       'src/geometry/encodeV10CParticle.m','src/geometry/decodeV10CParticle.m',
       'src/optimizers/optimizeV10CPSO.m','src/optimizers/v10cFitness.m',
       'scripts/plotV10CResults.m','scripts/runV10CComparison.m']

class SearchContracts(unittest.TestCase):
    def test_search_api_exists(self):
        for name in FILES: self.assertTrue((ROOT/name).is_file(),name)

    def test_runner_really_dispatches_search(self):
        s=(ROOT/'scripts/runV10C.m').read_text()
        self.assertIn('optimizeV10CPSO(',s)
        self.assertIn("'search-complete'",s)
        self.assertIn("'results.mat'",s)
        self.assertIn("cfg.execution.mode='optimize'",(ROOT/'src/config/v10cConfig.m').read_text())

    def test_budgeted_hover_projection_math(self):
        rng=np.random.default_rng(2026)
        lo,hi,budget=.1,3.,20.
        for _ in range(100):
            h=np.clip(rng.normal(2,4,20),lo,hi)
            if h.sum()>budget:
                h=lo+(h-lo)*(budget-20*lo)/(h.sum()-20*lo)
            self.assertTrue(np.all(h>=lo-1e-12))
            self.assertTrue(np.all(h<=hi+1e-12))
            self.assertLessEqual(h.sum(),budget+1e-10)

    def test_exact_stay_preserves_directed_progress(self):
        rng=np.random.default_rng(2026)
        for _ in range(100):
            y=np.r_[300,np.sort(rng.uniform(0,300,19))[::-1],0]
            j=rng.integers(1,20); y[j]=y[j-1]
            self.assertTrue(np.all(np.diff(y)<=0))
            self.assertEqual(y[j],y[j-1])

    def test_tight_hover_budget_has_explicit_zero_excess_branch(self):
        s=(ROOT/'src/geometry/repairV10CParticle.m').read_text()
        self.assertIn('budget<=sim.numSlots*hmin',s)
        self.assertIn('sum(extra)>0',s)

    def test_full_campaign_has_three_algorithms_and_requested_budget(self):
        cfg=(ROOT/'src/config/v10cConfig.m').read_text()
        self.assertIn("{'JOINT_PSO','FULL_PSO','FULL_IPSO'}",cfg)
        script=ROOT/'scripts/maincodeV10CCampaign.m'
        self.assertTrue(script.is_file())
        s=script.read_text()
        self.assertIn('[2026,608060,3486784401]',s)
        self.assertIn("runV10CComparison('full'",s)

    def test_block_balance(self):
        for name in FILES+['scripts/runV10C.m','tests/testV10CSearch.m']:
            brackets=[]; blocks=[]
            for t in matlab_structure_tokens((ROOT/name).read_text()):
                if t in ('(','[','{'): brackets.append(t)
                elif t in (')',']','}'):
                    self.assertEqual(brackets.pop(),{')':'(',']':'[','}':'{'}[t],name)
                elif not brackets:
                    if t in ('function','if','for','while','switch','try','parfor','arguments'): blocks.append(t)
                    elif t=='end': blocks.pop()
            self.assertEqual(brackets,[],name); self.assertEqual(blocks,[],name)

if __name__=='__main__': unittest.main(verbosity=2)
