"""Source-contract checks only. This script never starts MATLAB/Octave."""
from pathlib import Path
import hashlib
import json
import math
import re
import sys
import unittest
from types import SimpleNamespace

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
V10_SOURCES = {
    "v10Config": "src/config/v10Config.m",
    "buildV10Simulation": "src/config/buildV10Simulation.m",
    "dronePropulsionPower": "src/models/dronePropulsionPower.m",
    "v10Channel": "src/models/v10Channel.m",
    "findAchievableRateV10": "src/models/findAchievableRateV10.m",
    "evaluateTrajectoryV10": "src/evaluators/evaluateTrajectoryV10.m",
    "addV10EnergyMetrics": "src/evaluators/addV10EnergyMetrics.m",
    "optimizeTrajectoryV10JointPSO": "src/optimizers/optimizeTrajectoryV10JointPSO.m",
    "optimizeTrajectoryV10FullPSO": "src/optimizers/optimizeTrajectoryV10FullPSO.m",
    "optimizeTrajectoryV10FullIPSO": "src/optimizers/optimizeTrajectoryV10FullIPSO.m",
    "polishAlphaV10": "src/optimizers/polishAlphaV10.m",
    "decodeV10Particle": "src/geometry/decodeV10Particle.m",
    "initialV10Particle": "src/geometry/initialV10Particle.m",
    "repairV10Particle": "src/geometry/repairV10Particle.m",
    "v10ParticleLayout": "src/geometry/v10ParticleLayout.m",
    "runV10": "scripts/runV10.m",
    "plotV10Diagnostics": "scripts/plotV10Diagnostics.m"
}
REQUIRED = ["scripts/maincodeV10A_EE.m", "scripts/maincodeV10B_EE.m", *V10_SOURCES.values()]



def matlab_structure_tokens(source):
    """Lexical structural scan only, not a MATLAB parser or runtime."""
    tokens=[]; i=0; last=''
    while i<len(source):
        char=source[i]
        if char=='%':
            i=source.find('\n',i)
            if i<0:
                break
            last=''; continue
        if char=='\n':
            last=''; i+=1; continue
        if char in ("'",'"'):
            # MATLAB conjugate/nonconjugate transpose after an expression.
            if char=="'" and last and (last.isalnum() or last in '_)]}.'):
                i+=1; last="'"; continue
            quote=char; i+=1
            while i<len(source):
                if source[i]==quote:
                    if i+1<len(source) and source[i+1]==quote:
                        i+=2; continue
                    i+=1; break
                i+=1
            else:
                raise AssertionError('Unterminated source string')
            last=''; continue
        if char.isalpha() or char=='_':
            j=i+1
            while j<len(source) and (source[j].isalnum() or source[j]=='_'):
                j+=1
            tokens.append(source[i:j]); last=source[j-1]; i=j; continue
        if char in '()[]{}':
            tokens.append(char)
        if not char.isspace():
            last=char
        i+=1
    return tokens


class V10SourceContracts(unittest.TestCase):
    def test_plot_bs_count_does_not_depend_on_main_workspace(self):
        source=(ROOT/'scripts/plotV10Diagnostics.m').read_text()
        active='\n'.join(line.split('%',1)[0] for line in source.splitlines())
        self.assertNotRegex(active,r'\b1\s*:\s*noBS\b')
        self.assertEqual(len(re.findall(r'for b\s*=\s*1\s*:\s*sim\.noBS\b',active)),3)

    def test_figure_group_switches_default_on_and_gate_each_range(self):
        config=(ROOT/'src/config/v10Config.m').read_text()
        plot=(ROOT/'scripts/plotV10Diagnostics.m').read_text()
        runner=(ROOT/'scripts/runV10.m').read_text()
        for group in ('base','EH_Alpha_config','flyingEnergy'):
            self.assertIn(f'cfg.output.figureGroups.{group} = true;',config)
            self.assertIn(f'if groups.{group}',plot)
        base=plot.split('    if groups.base\n',1)[1].split('    if groups.EH_Alpha_config\n',1)[0]
        eh=plot.split('    if groups.EH_Alpha_config\n',1)[1].split('    if groups.flyingEnergy\n',1)[0]
        flying=plot.split('    if groups.flyingEnergy\n',1)[1]
        for number in (1,2,4,5):
            self.assertIn(f'figure({number})',base)
        self.assertIn('figure(5+panel)',base)
        for number in (9,10,12):
            self.assertIn(f'figure({number})',eh)
        self.assertIn('figure(11)',eh)
        self.assertIn('figure(13)',eh)
        self.assertIn('figure(13+k)',eh)
        for number in (17,18):
            self.assertIn(f'figure({number})',flying)
        self.assertIn('if ~didPlot',plot)
        self.assertIn('cfg.output.saveFigures && didPlot',runner)

    def test_required_sources_exist(self):
        for relative in REQUIRED:
            self.assertTrue((ROOT / relative).is_file(), relative)

    def test_unique_function_names_and_file_names(self):
        declared = {}
        for relative in REQUIRED:
            path = ROOT / relative
            if not path.exists():
                continue
            source = path.read_text()
            if relative in V10_SOURCES.values():
                match = re.search(r"^function\s+(?:\[[^\]]+\]\s*=\s*|\w+\s*=\s*)?(\w+)\s*\(", source)
                self.assertIsNotNone(match, relative)
                self.assertEqual(match.group(1), path.stem)
                self.assertNotIn(path.stem, declared)
                declared[path.stem] = path
                for old in [*(ROOT / "src").rglob(path.name), *(ROOT / "scripts").glob(path.name)]:
                    self.assertEqual(old, path, f"Function shadowing: {old}")

    def test_lexical_delimiters_and_control_blocks(self):
        for relative in REQUIRED+['tests/testV10Models.m']:
            brackets=[]; blocks=[]
            for token in matlab_structure_tokens((ROOT/relative).read_text()):
                if token in ('(', '[', '{'):
                    brackets.append(token)
                elif token in (')', ']', '}'):
                    self.assertTrue(brackets, relative)
                    self.assertEqual(brackets.pop(),{')':'(',']':'[','}':'{'}[token],relative)
                elif not brackets:
                    if token in ('function','if','for','while','switch','try','parfor','arguments'):
                        blocks.append(token)
                    elif token=='end':
                        self.assertTrue(blocks,relative)
                        blocks.pop()
            self.assertEqual(brackets,[],relative)
            self.assertEqual(blocks,[],relative)

    def test_v10_has_no_legacy_fitness_or_rate_dispatch(self):
        for relative in V10_SOURCES.values():
            path = ROOT / relative
            source = path.read_text()
            for forbidden in ("evaluateTrajectory_Joint", "findAchievableRate_SWIPT(",
                              "findAchievableRate_SWIPT_Joint(", "'ee-rf'", "evalin(", "assignin("):
                self.assertNotIn(forbidden, source, str(path))

    def test_v9_unchanged_against_snapshot(self):
        # Snapshot predates V10 and includes the user's preexisting uncommitted edits.
        snapshot = ROOT / 'tests/fixtures/v9_matlab_sha256_before_v10.json'
        if not snapshot.exists():
            self.skipTest("No pre-change snapshot on this machine")
        for relative, expected in json.loads(snapshot.read_text()).items():
            self.assertEqual(hashlib.sha256((ROOT / relative).read_bytes()).hexdigest(), expected, relative)

    def test_v9_velocity_and_ipso_rules_preserved(self):
        for old, new in (
            ('optimizeTrajectory_JointPSO_SWIPT_clean','optimizeTrajectoryV10JointPSO'),
            ('optimizeTrajectory_JointBS_PSO_SWIPT_clean','optimizeTrajectoryV10FullPSO'),
            ('optimizeTrajectory_JointBS_IPSO_SWIPT_clean','optimizeTrajectoryV10FullIPSO'),
        ):
            source = (ROOT / 'src/optimizers' / (old+'.m')).read_text()
            target = (ROOT / V10_SOURCES[new]).read_text()
            for line in source.splitlines():
                if any(key in line for key in (
                    'particlesVel(i, :) = w', 'w_current =', 'stallCount =',
                    'mutMask =', 'sigma = curSigmaScale', 'trialPos(mutMask) =',
                    'if fitTrial > pbestVal(k)',
                )):
                    self.assertIn(line.strip(), target, new)

    def test_actual_propulsion_expressions_against_numeric_reference(self):
        # Evaluate only the straight-line arithmetic assignments from the .m source.
        # This is NOT a MATLAB parser/runtime and does not validate MATLAB execution.
        text = (ROOT / 'src/models/dronePropulsionPower.m').read_text()
        text = text[text.index('    n=flight.numRotors;'):text.rindex('\nend')]
        text = re.sub(r'%[^\n]*', '', text).replace('...', '').replace('\n', ' ')
        f = SimpleNamespace(numRotors=4, airDensity=1.293, flatPlateArea=.01,
                            mass=2, gravity=9.8, rotorSolidity=.0955,
                            bladeDrag=.012, thrustCoefficient=.302,
                            inducedCorrection=.131, fuselageDragRatio=.8333, rotorArea=.0314)
        env = {'flight': f, 'speed': np.array([0.,15.,15.521]),
               'parts': SimpleNamespace(), 'hypot': np.hypot, 'sqrt': np.sqrt}
        for statement in text.split(';'):
            statement = statement.strip()
            if not statement:
                continue
            lhs, rhs = statement.split('=',1)
            rhs = rhs.replace('.^','**').replace('^','**').replace('.*','*').replace('./','/')
            value = eval(rhs, {'__builtins__': {}}, env)
            lhs = lhs.strip()
            if lhs.startswith('parts.'):
                setattr(env['parts'],lhs.split('.',1)[1],value)
            else:
                env[lhs] = value
        np.testing.assert_allclose(env['power'],
            [172.38763327964966,109.08979290694944,108.9407871807112],rtol=1e-12)
        np.testing.assert_allclose(env['parts'].thrustPerRotor[0],4.9,rtol=1e-12)

    def test_directed_progress_arithmetic_forward_reverse_and_tight(self):
        # Independent property check for the documented B repair construction.
        random = np.random.default_rng(2026)
        for start,end,gap in [(300.,0.,1.),(0.,300.,1.),(300.,0.,15.)]:
            n=19; direction=np.sign(end-start); slack=abs(end-start)-20*gap
            for _ in range(1000):
                proposed=random.uniform(-1e5,1e5,n)
                index=np.arange(1,n+1)
                residual=np.sort(np.clip(direction*(proposed-start)-index*gap,0,slack))
                y=np.r_[start,start+direction*(index*gap+residual),end]
                self.assertTrue(np.all(direction*np.diff(y)>=gap-1e-10))
                self.assertTrue(np.all(y>=min(start,end)) and np.all(y<=max(start,end)))

    def test_radio_constants_are_only_configured_in_config(self):
        source = (ROOT / 'src/models/findAchievableRateV10.m').read_text()
        for key in ('r.bsPowerW','r.bandwidthHz','r.noisePowerW','r.powerSplit',
                    'r.ehEfficiency','sim.ehTime','sim.rfTime'):
            self.assertIn(key,source)
        self.assertNotIn('1e-6',source)
        self.assertNotIn('46',source)
        self.assertNotIn('0.9',source)
        self.assertNotIn('sim.pMin',source,
                         'Rate helper must not floor normalized alpha a second time')

    def test_energy_and_output_scope_contract(self):
        source=(ROOT/'src/evaluators/addV10EnergyMetrics.m').read_text()
        self.assertIn('result.totalEnergy=sum(result.energyPerSlot)',source)
        self.assertIn('result.flightEnergyPerSlot+result.hoverEnergyPerSlot+result.rfEnergyPerSlot',source)
        self.assertIn('result.batteryEnergyIdeal=result.flightEnergy+result.hoverEnergy',source)
        for name in ('optimizeTrajectoryV10JointPSO','optimizeTrajectoryV10FullPSO','optimizeTrajectoryV10FullIPSO'):
            target=(ROOT / V10_SOURCES[name]).read_text()
            self.assertIn('isempty(fieldnames(gbestRes)) || fit_i > gbestVal',target)
            for history in ('flightEnergyHistory','hoverEnergyHistory','rfEnergyHistory','feasibleHistory'):
                self.assertIn(f'best.{history} = {history};',target)


if __name__ == "__main__":
    unittest.main(verbosity=2)
