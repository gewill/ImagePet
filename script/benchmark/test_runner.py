import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('benchmark_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class MeasurementTests(unittest.TestCase):
    def test_high_water_memory_and_large_output(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'output.log'
            result = runner.measure([sys.executable, '-c',
                                     'a=bytearray(64*1024*1024); print("x"*1000000); del a'], log)
            self.assertEqual(result['exit_code'], 0)
            self.assertGreater(result['peak_rss_bytes'], 64 * 1024 * 1024)
            self.assertGreater(result['seconds'], 0)
            self.assertGreater(log.stat().st_size, 1000000)

    def test_nonzero_exit_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            result = runner.measure([sys.executable, '-c', 'raise SystemExit(7)'], Path(directory) / 'log')
            self.assertEqual(result['exit_code'], 7)

    def test_nearest_rank_percentiles_include_tail(self):
        self.assertEqual(runner.percentile([4, 1, 3, 2], .5), 2)
        self.assertEqual(runner.percentile([4, 1, 3, 2], .95), 4)
        self.assertIsNone(runner.percentile([], .5))


class EffectivenessTests(unittest.TestCase):
    def test_skips_remain_in_denominator_and_failures_are_not_hidden(self):
        spec = importlib.util.spec_from_file_location('compare_runs', Path(__file__).with_name('compare_runs.py'))
        comparison = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(comparison)
        self.assertEqual(comparison.effective_bytes({'status': 'done', 'output_bytes': 40, 'input_bytes': 100}), 40)
        self.assertEqual(comparison.effective_bytes({'status': 'skipped_not_smaller', 'output_bytes': None, 'input_bytes': 100}), 100)
        with self.assertRaises(ValueError):
            comparison.effective_bytes({'status': 'failed', 'input_bytes': 100})


if __name__ == '__main__':
    unittest.main()
