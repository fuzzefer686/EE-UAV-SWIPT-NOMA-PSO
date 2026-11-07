"""Behavior tests for the cross-version guard, with controlled MATLAB snippets."""
import unittest
import check_v11_static as guard

def legacy_v10_references(*args):
    assert hasattr(guard,'legacy_v10_references'), 'Cross-version guard is missing'
    return guard.legacy_v10_references(*args)

class V11GuardTests(unittest.TestCase):
    def test_detects_active_calls_and_function_handles_with_locations(self):
        found=legacy_v10_references('src/evaluators/evaluateTrajectoryV11.m',
            'x = v10Channel(p);\ny = @findAchievableRateV10;\nfeval(\'polishAlphaV10\',x);\n')
        self.assertEqual([(x[1],x[2]) for x in found],[(1,'v10Channel('),(2,'findAchievableRateV10'),(3,'polishAlphaV10')])
    def test_ignores_comments_without_confusing_percent_formats_or_transposes(self):
        source="% evaluateTrajectoryV10(x)\nfprintf('%d',1); v10Config(); % v10Channel(x)\na=x'; % polishAlphaV10\n%{\nrunV10(x)\n%}\n"
        found=legacy_v10_references('scripts/runV11.m',source)
        self.assertEqual([(x[1],x[2]) for x in found],[(2,'v10Config(')])
    def test_block_markers_must_be_standalone_lines(self):
        ordinary="%{ prose on an ordinary comment line\nx = v10Config();\n"
        found=legacy_v10_references('scripts/runV11.m',ordinary)
        self.assertEqual([(x[1],x[2]) for x in found],[(2,'v10Config(')])
        block="  %{  \n%} trailing text does not close the block\nv10Config();\n  %}  \nv10Channel(x);\n"
        found=legacy_v10_references('scripts/runV11.m',block)
        self.assertEqual([(x[1],x[2]) for x in found],[(5,'v10Channel(')])
    def test_only_approved_comparator_can_call_v10(self):
        self.assertEqual(legacy_v10_references('scripts/compareV11V10Equivalence.m','runV10(x);'),[])
        self.assertTrue(legacy_v10_references('scripts/runV11.m','runV10(x);'))
        self.assertTrue(legacy_v10_references('src/models/compareV11V10Equivalence.m','runV10(x);'))
    def test_v11_calls_and_protected_test_exception(self):
        self.assertEqual(legacy_v10_references('src/models/findAchievableRateV11.m','rate=findAchievableRateV11(x);'),[])
        self.assertEqual(legacy_v10_references('tests/testV11Models.m','runV10(x);'),[])

if __name__=='__main__': unittest.main(verbosity=2)
