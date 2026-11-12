"""Source contracts + independent mathematics, NOT MATLAB runtime tests."""
from pathlib import Path
import hashlib
import json
import math
import re
import unittest
import numpy as np
from check_v10_static import matlab_structure_tokens

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    'src/config/v10cConfig.m', 'src/config/buildV10CSimulation.m',
    'src/geometry/initialV10CCandidate.m', 'src/geometry/v10cGeometryLayout.m',
    'src/geometry/decodeV10CGeometry.m', 'src/models/v10cMotionEnergy.m',
    'src/evaluators/evaluateV10CCandidate.m', 'src/models/v10cTimeBlockData.m',
    'scripts/runV10C.m', 'scripts/maincodeV10C_EE.m',
]

class V10CContracts(unittest.TestCase):
    def test_api_exists(self):
        for path in SOURCES:
            self.assertTrue((ROOT/path).is_file(),path)

    def test_presets_and_default(self):
        source=(ROOT/SOURCES[0]).read_text()
        self.assertIn("preset='C4'",source)
        for k in range(6):
            self.assertIn(f"case 'C{k}'",source)
        self.assertIn('allowExperimental=false',source)

    def test_status_and_no_fake_hybrid_solver(self):
        source=(ROOT/'scripts/runV10C.m').read_text()
        self.assertIn('initialized-not-optimized',source)
        self.assertNotIn('fmincon(',source)
        self.assertIn('optimizeV10CPSO(',source)
        self.assertIn('SCA/Dinkelbach hybrid not used',source)
        self.assertIn('result.isOptimized=false',
                      (ROOT/'src/evaluators/evaluateV10CCandidate.m').read_text())

    def test_geometry_particle_excludes_resource_blocks(self):
        source=(ROOT/'src/geometry/v10cGeometryLayout.m').read_text()
        self.assertNotIn('layout.alpha=',source)
        self.assertNotIn('layout.hover=',source)
        self.assertNotIn('layout.uplink=',source)

    def test_inherited_model_is_not_labeled_empirically_validated(self):
        source=(ROOT/'src/config/buildV10CSimulation.m').read_text()
        self.assertIn('sim.modelInherited=',source)
        self.assertNotIn('sim.modelValidated=',source)

    def test_structural_delimiters(self):
        for path in SOURCES+['tests/testV10CModels.m']:
            tokens=matlab_structure_tokens((ROOT/path).read_text())
            stack=[]; blocks=[]
            for token in tokens:
                if token in ('(','[','{'): stack.append(token)
                elif token in (')',']','}'):
                    self.assertTrue(stack,path)
                    self.assertEqual(stack.pop(),{')':'(',']':'[','}':'{'}[token],path)
                elif not stack:
                    if token in ('function','if','for','while','switch','try','parfor','arguments'):
                        blocks.append(token)
                    elif token=='end':
                        self.assertTrue(blocks,path)
                        blocks.pop()
            self.assertFalse(stack,path)
            self.assertFalse(blocks,path)

    def test_function_names_and_no_shadowing(self):
        for name in SOURCES:
            path=ROOT/name
            if path.stem.startswith('maincode'): continue
            match=re.search(r'^function\s+(?:\[[^\]]+\]\s*=\s*|\w+\s*=\s*)?(\w+)\s*\(',path.read_text())
            self.assertIsNotNone(match,name)
            self.assertEqual(match[1],path.stem,name)
            found=list((ROOT/'src').rglob(path.name))+list((ROOT/'scripts').glob(path.name))
            self.assertEqual(found,[path])

    def test_legacy_source_preservation(self):
        fixture=ROOT/'tests/fixtures/v10c_initialization_preservation.json'
        for name,expected in json.loads(fixture.read_text()).items():
            self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),expected,name)

    def test_independent_time_block_identity_and_curvature(self):
        rng=np.random.default_rng(2026)
        for _ in range(100):
            alpha=rng.dirichlet(np.ones(5)); alpha=np.sort(alpha)[::-1]
            gain=np.sort(rng.uniform(0.1,4,5)); noise=0.3; harvest=0.7
            u,v=rng.uniform(0.05,2,2)
            tail=np.cumsum(alpha[::-1])[::-1]-alpha
            pt=harvest*u/v
            direct=v*np.log2(1+pt*alpha*gain/(noise+pt*gain*tail))
            a=harvest*alpha*gain/noise; b=harvest*gain*tail/noise
            perspective=v*np.log2(1+a*u/(v+b*u))
            np.testing.assert_allclose(direct,perspective,rtol=1e-12)
            f=lambda x: v*np.log2(1+a*x/(v+b*x))
            self.assertTrue(np.all(f(u+1e-3)-2*f(u)+f(u-1e-3)<=1e-10))

    def test_independent_motion_profile(self):
        speed=15.521; accel=2.0; threshold=speed*speed/accel
        def time(d):
            return 2*math.sqrt(d/accel) if d<=threshold else d/speed+speed/accel
        self.assertEqual(time(0),0)
        self.assertAlmostEqual(time(threshold),2*speed/accel)
        self.assertAlmostEqual(time(threshold-1e-7),time(threshold+1e-7),places=7)
        self.assertGreater(time(1),1/speed)

if __name__=='__main__':
    unittest.main(verbosity=2)
