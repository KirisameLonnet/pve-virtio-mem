#!/usr/bin/env python3
"""Guard experimental acceptance against reporting false reclamation success."""
import copy
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / 'experimental/transparent/accept.py'
spec = importlib.util.spec_from_file_location('transparent_accept', path)
accept = importlib.util.module_from_spec(spec)
spec.loader.exec_module(accept)


class AcceptanceContract(unittest.TestCase):
    def setUp(self):
        self.total = 500 * 1024
        self.payload = 448 * 1024 * 1024
        names = ['baseline', 'allocated_1', 'freed_1', 'idle_1',
                 'allocated_2', 'freed_2', 'idle_2', 'pass']
        self.phases = {
            name: {'phase': name, 'mem_total_kib': self.total,
                   'allocation_bytes': self.payload} for name in names
        }
        self.samples = {
            'allocated_1': [540 << 20, 550 << 20],
            'freed_1': [540 << 20, 90 << 20],
            'allocated_2': [542 << 20, 552 << 20],
            'freed_2': [545 << 20, 92 << 20],
        }

    def check(self):
        return accept.validate(self.phases, self.samples, 512)

    def test_completed_reuse_and_physical_reclaim(self):
        result = self.check()
        self.assertEqual(result['guest_mem_total_kib'], self.total)
        self.assertEqual(result['reclaimed_bytes'], [460 << 20, 460 << 20])
        self.assertIn('no VFIO', result['scope'])

    def test_hot_unplug_cannot_count_as_transparent_reclaim(self):
        self.phases['freed_1']['mem_total_kib'] -= 128 * 1024
        with self.assertRaisesRegex(RuntimeError, 'capacity changed'):
            self.check()

    def test_small_guest_cannot_count_as_full_configured_capacity(self):
        for record in self.phases.values():
            record['mem_total_kib'] = 64 * 1024
        with self.assertRaisesRegex(RuntimeError, 'configured memory'):
            self.check()

    def test_unused_small_allocation_cannot_count_as_demand_reuse(self):
        self.phases['allocated_2']['allocation_bytes'] = 16 << 20
        with self.assertRaisesRegex(RuntimeError, 'most of its visible capacity'):
            self.check()

    def test_one_successful_reclaim_does_not_hide_second_failure(self):
        self.samples['freed_2'] = [545 << 20, 540 << 20]
        with self.assertRaisesRegex(RuntimeError, 'round 2'):
            self.check()

    def test_capacity_markers_alone_do_not_prove_physical_reclaim(self):
        self.samples = {}
        with self.assertRaisesRegex(RuntimeError, 'physical-memory measurements'):
            self.check()

    def test_partial_or_reordered_workload_cannot_pass(self):
        original = copy.deepcopy(self.phases)
        for name in original:
            with self.subTest(missing=name):
                self.phases = copy.deepcopy(original)
                del self.phases[name]
                with self.assertRaisesRegex(RuntimeError, 'both allocation/reuse cycles'):
                    self.check()
        self.phases = dict(reversed(list(original.items())))
        with self.assertRaisesRegex(RuntimeError, 'both allocation/reuse cycles'):
            self.check()


if __name__ == '__main__':
    unittest.main()
