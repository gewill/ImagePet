import unittest
import numpy as np
from quality_report import score_rgba


class QualityTests(unittest.TestCase):
    def test_identical_signal_scores_one(self):
        image = np.zeros((32, 32, 4), dtype=np.uint8)
        image[:, :, 3] = 255
        image[8:24, 8:24, :3] = 200
        self.assertEqual(score_rgba(image, image)['ssim'], 1.0)

    def test_alpha_loss_is_visible_on_white_even_when_black_matches(self):
        transparent = np.zeros((32, 32, 4), dtype=np.uint8)
        opaque = transparent.copy()
        opaque[:, :, 3] = 255
        result = score_rgba(transparent, opaque)
        self.assertEqual(result['black_background_ssim'], 1.0)
        self.assertLess(result['white_background_ssim'], 0.01)
        self.assertEqual(result['ssim'], result['white_background_ssim'])

    def test_detail_damage_reduces_score_and_resize_is_not_hidden(self):
        original = np.full((32, 32, 4), 255, dtype=np.uint8)
        changed = original.copy()
        changed[::2, :, :3] = 0
        self.assertLess(score_rgba(original, changed)['ssim'], 0.5)
        with self.assertRaises(ValueError):
            score_rgba(original, changed[:16])


if __name__ == '__main__':
    unittest.main()
