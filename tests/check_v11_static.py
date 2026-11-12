"""V11 source/preservation checks. Runtime assertions live in testV11Models.m."""
from pathlib import Path
import ast
import hashlib
import json
import re
import unittest
from check_v10_static import matlab_structure_tokens
ROOT = Path(__file__).resolve().parents[1]
OLD = ast.parse((ROOT/'tests/check_v10_static.py').read_text())
V10_SOURCES = next(ast.literal_eval(n.value) for n in OLD.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='V10_SOURCES' for t in n.targets))
V11_SOURCES = {k.replace('V10','V11').replace('v10','v11'): v.replace('V10','V11').replace('v10','v11') for k,v in V10_SOURCES.items() if k!='dronePropulsionPower'}
EXTRA = ['src/geometry/alphaPolicyV11.m','src/optimizers/solveAlphaQoSV11.m','src/config/v11AlphaPreset.m','scripts/runV11AlphaStudy.m','scripts/maincodeV11A_EE.m','scripts/maincodeV11B_EE.m','tests/testV11Models.m','tests/testV11JointFinalization.m','tests/testV11EquivalenceScript.m','scripts/compareV11V10Equivalence.m','scripts/writeV11AlphaStudySummary.m','tests/testV11AlphaStudyEdges.m','tests/testV11BaselineFixture.m']

# Explicitly approved comparison harness; all operational V11 code is guarded.
V10_COMPARISON_EXCEPTION = "scripts/compareV11V10Equivalence.m"
LEGACY_NAMES = ("polishAlphaV10", "evaluateTrajectoryV10", "findAchievableRateV10",
                "v10Channel", "addV10EnergyMetrics", "adV10EnergyMetrics",
                "v10ParticleLayout", "buildV10Simulation", "v10Config")
LEGACY_CALL = re.compile(r"\b[a-zA-Z_]*[vV]10[a-zA-Z_0-9]*\s*\(|\b(?:" + "|".join(LEGACY_NAMES) + r")\b")


def standalone_block_marker(source,index,marker):
    start=source.rfind('\n',0,index)+1
    end=source.find('\n',index)
    if end<0: end=len(source)
    return source[start:end].strip()==marker


def strip_matlab_comments(source):
    """Preserve line numbers, quoted formats and transpose; mask comments only.

    Named legacy handles/feval strings are intentionally guarded too.
    """
    out=list(source); quote=None; block=False; i=0
    while i<len(source):
        char=source[i]
        if block:
            if source.startswith('%}',i) and standalone_block_marker(source,i,'%}'):
                out[i:i+2]=[' ',' ']; i+=2; block=False; continue
            if char!='\n': out[i]=' '
            i+=1; continue
        if quote:
            if char==quote:
                if i+1<len(source) and source[i+1]==quote:
                    i+=2; continue
                quote=None
            i+=1; continue
        if char=='%':
            if source.startswith('%{',i) and standalone_block_marker(source,i,'%{'):
                out[i:i+2]=[' ',' ']; i+=2; block=True; continue
            while i<len(source) and source[i]!='\n': out[i]=' '; i+=1
            continue
        if char in ("'",'"'):
            previous=source[i-1] if i else ''
            transpose=char=="'" and previous and (previous.isalnum() or previous in '_)]}.')
            if not transpose: quote=char
        i+=1
    return ''.join(out)


def legacy_v10_references(relative,source):
    relative=Path(relative).as_posix()
    if relative.startswith('tests/') or relative==V10_COMPARISON_EXCEPTION:
        return []
    active=strip_matlab_comments(source)
    return [(relative,active.count('\n',0,m.start())+1,m.group()) for m in LEGACY_CALL.finditer(active)]


def v11_matlab_sources():
    return sorted(set((ROOT/'src').rglob('*V11*.m')) | set((ROOT/'src').rglob('v11*.m'))
                  | set((ROOT/'scripts').glob('*V11*.m')))

class V11Contracts(unittest.TestCase):
    def test_no_operational_v11_calls_to_v10(self):
        found=[]
        for path in v11_matlab_sources():
            found.extend(legacy_v10_references(path.relative_to(ROOT),path.read_text()))
        self.assertEqual(found,[],"\n".join(f"{p}:{line}: {match}" for p,line,match in found))

    def test_protected_checksums(self):
        for fixture in ('v9_matlab_sha256_before_v10.json','v10_matlab_sha256_before_v11.json'):
            for p,h in json.loads((ROOT/'tests/fixtures'/fixture).read_text()).items():
                self.assertEqual(hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),h,p)
    def test_snapshot_coverage(self):
        expected=set(json.loads((ROOT/'tests/fixtures/v9_matlab_sha256_before_v10.json').read_text()))|set(V10_SOURCES.values())
        # This is the frozen pre-V11 snapshot, not future V10C entry points.
        expected|={'scripts/maincodeV10A_EE.m','scripts/maincodeV10B_EE.m',
                   'scripts/maincodeV10Campaign.m'}
        self.assertEqual(set(json.loads((ROOT/'tests/fixtures/v10_matlab_sha256_before_v11.json').read_text())),expected)
    def test_required_files(self):
        for p in [*V11_SOURCES.values(),*EXTRA]: self.assertTrue((ROOT/p).is_file(),p)
    def test_physics_verbatim(self):
        for name in ('v10Channel','findAchievableRateV10','addV10EnergyMetrics'):
            old=(ROOT/V10_SOURCES[name]).read_text()
            new=old.replace('V10','V11').replace('v10','v11')
            self.assertEqual((ROOT/V11_SOURCES[name.replace('V10','V11').replace('v10','v11')]).read_text(),new)
    def test_names_and_lexical_structure(self):
        for p in [*V11_SOURCES.values(),*EXTRA]:
            source=(ROOT/p).read_text(); path=ROOT/p
            if not path.stem.startswith('maincode'):
                m=re.search(r'^function\s+(?:\[[^\]]+\]\s*=\s*|\w+\s*=\s*)?(\w+)\s*\(',source)
                self.assertIsNotNone(m,p); self.assertEqual(m[1],path.stem,p)
                duplicates=list((ROOT/'src').rglob(path.name))+list((ROOT/'scripts').glob(path.name))
                if p.startswith(('src/','scripts/')): self.assertEqual(duplicates,[path],p)
            brackets=[]; blocks=[]
            for token in matlab_structure_tokens(source):
                if token in ('(','[','{'): brackets.append(token)
                elif token in (')',']','}'):
                    self.assertTrue(brackets,p); self.assertEqual(brackets.pop(),{')':'(',']':'[','}':'{'}[token],p)
                elif not brackets:
                    if token in ('function','if','for','while','switch','try','parfor','arguments'): blocks.append(token)
                    elif token=='end': self.assertTrue(blocks,p); blocks.pop()
            self.assertEqual(brackets,[],p); self.assertEqual(blocks,[],p)
if __name__=='__main__': unittest.main(verbosity=2)
