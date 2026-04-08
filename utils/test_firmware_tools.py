#!/usr/bin/env python3
"""
Tests for PhoenixBoot firmware analysis tools.

Validates the firmware_baseline_analyzer and hardware_firmware_recovery
utilities using in-memory synthetic firmware data (no real hardware needed).
"""

import hashlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

# Add utils directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from firmware_baseline_analyzer import FirmwareAnalyzer
from hardware_firmware_recovery import HardwareFirmwareRecovery


def make_synthetic_firmware(size=0x2000):
    """Create a small synthetic firmware blob containing known UEFI signatures."""
    data = bytearray(size)

    # Embed a fake Firmware Volume Header signature at offset 0x200
    fv_offset = 0x200
    data[fv_offset:fv_offset + 4] = b'_FVH'

    # Embed a fake AMI BIOSGuard signature at offset 0x400
    ami_offset = 0x400
    data[ami_offset:ami_offset + 8] = b'_AMIPFAT'

    # Embed a minimal DER-like certificate header at offset 0x600
    # ASN.1 SEQUENCE (0x30 0x82) + 2-byte length (0x02 0x00 = 512 bytes, reasonable)
    cert_offset = 0x600
    cert_len = 512
    data[cert_offset] = 0x30
    data[cert_offset + 1] = 0x82
    data[cert_offset + 2] = (cert_len >> 8) & 0xFF
    data[cert_offset + 3] = cert_len & 0xFF
    # Fill cert body with recognisable bytes
    for i in range(4, min(4 + cert_len, size - cert_offset)):
        data[cert_offset + i] = 0xAB

    return bytes(data)


class TestFirmwareAnalyzer(unittest.TestCase):
    """Tests for FirmwareAnalyzer."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="pg_fw_test_")
        self.firmware_path = os.path.join(self.tmp_dir, "test_firmware.bin")
        self.firmware_data = make_synthetic_firmware()
        with open(self.firmware_path, 'wb') as f:
            f.write(self.firmware_data)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    # ------------------------------------------------------------------
    # Initialisation
    # ------------------------------------------------------------------

    def test_default_hardware_model(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        self.assertEqual(analyzer.hardware_model, "Unknown")
        self.assertEqual(analyzer.bios_version, "Unknown")

    def test_custom_hardware_model(self):
        analyzer = FirmwareAnalyzer(
            self.firmware_path,
            hardware_model="ASUS ROG G615LP",
            bios_version="AS.325",
        )
        self.assertEqual(analyzer.hardware_model, "ASUS ROG G615LP")
        self.assertEqual(analyzer.bios_version, "AS.325")

    # ------------------------------------------------------------------
    # load_firmware
    # ------------------------------------------------------------------

    def test_load_firmware_success(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        self.assertTrue(analyzer.load_firmware())
        self.assertEqual(len(analyzer.firmware_data), len(self.firmware_data))

    def test_load_firmware_missing_file(self):
        analyzer = FirmwareAnalyzer("/nonexistent/firmware.bin")
        self.assertFalse(analyzer.load_firmware())

    # ------------------------------------------------------------------
    # calculate_hashes
    # ------------------------------------------------------------------

    def test_calculate_hashes_returns_full_sha256(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        hashes = analyzer.calculate_hashes()
        expected = hashlib.sha256(self.firmware_data).hexdigest()
        self.assertEqual(hashes['full_sha256'], expected)

    def test_calculate_hashes_contains_chunk_hashes(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        hashes = analyzer.calculate_hashes()
        self.assertIn('chunk_hashes', hashes)
        self.assertIsInstance(hashes['chunk_hashes'], list)
        self.assertGreater(len(hashes['chunk_hashes']), 0)

    def test_calculate_hashes_chunk_format(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        hashes = analyzer.calculate_hashes()
        first_chunk = hashes['chunk_hashes'][0]
        self.assertIn('offset', first_chunk)
        self.assertIn('size', first_chunk)
        self.assertIn('sha256', first_chunk)
        self.assertEqual(first_chunk['offset'], '0x0')

    def test_calculate_hashes_empty_data(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        # Do not call load_firmware – firmware_data is None
        hashes = analyzer.calculate_hashes()
        self.assertEqual(hashes, {})

    # ------------------------------------------------------------------
    # find_signatures
    # ------------------------------------------------------------------

    def test_find_signatures_detects_fvh(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        sigs = analyzer.find_signatures()
        self.assertIn('uefi_fv_header', sigs)
        self.assertGreater(len(sigs['uefi_fv_header']), 0)

    def test_find_signatures_detects_ami(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        sigs = analyzer.find_signatures()
        self.assertIn('ami_bios_guard', sigs)

    def test_find_signatures_absent_signature(self):
        # The synthetic firmware has no 'DXE_CORE' string
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        sigs = analyzer.find_signatures()
        self.assertNotIn('dxe_core', sigs)

    # ------------------------------------------------------------------
    # extract_certificates
    # ------------------------------------------------------------------

    def test_extract_certificates_finds_embedded_cert(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        certs = analyzer.extract_certificates()
        # Our synthetic firmware has one certificate-like structure
        self.assertGreater(len(certs), 0)

    def test_extract_certificates_structure(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        certs = analyzer.extract_certificates()
        for key, cert in certs.items():
            self.assertIn('offset', cert)
            self.assertIn('length', cert)
            self.assertIn('sha256', cert)

    # ------------------------------------------------------------------
    # analyze_uefi_volumes
    # ------------------------------------------------------------------

    def test_analyze_uefi_volumes_finds_fv(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        volumes = analyzer.analyze_uefi_volumes()
        self.assertGreater(len(volumes), 0)

    def test_analyze_uefi_volumes_structure(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        volumes = analyzer.analyze_uefi_volumes()
        for key, vol in volumes.items():
            self.assertIn('offset', vol)
            self.assertIn('header_hash', vol)

    # ------------------------------------------------------------------
    # create_baseline
    # ------------------------------------------------------------------

    def test_create_baseline_structure(self):
        analyzer = FirmwareAnalyzer(
            self.firmware_path,
            hardware_model="TestBoard",
            bios_version="v1.0",
        )
        analyzer.load_firmware()
        baseline = analyzer.create_baseline()

        self.assertIn('metadata', baseline)
        self.assertIn('hashes', baseline)
        self.assertIn('signatures', baseline)
        self.assertIn('certificates', baseline)
        self.assertIn('uefi_volumes', baseline)
        self.assertIn('bootkit_indicators', baseline)

    def test_create_baseline_metadata(self):
        analyzer = FirmwareAnalyzer(
            self.firmware_path,
            hardware_model="TestBoard",
            bios_version="v1.0",
        )
        analyzer.load_firmware()
        baseline = analyzer.create_baseline()
        meta = baseline['metadata']

        self.assertEqual(meta['hardware_model'], "TestBoard")
        self.assertEqual(meta['bios_version'], "v1.0")
        self.assertEqual(meta['firmware_size'], len(self.firmware_data))

    def test_create_baseline_bootkit_indicators(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        baseline = analyzer.create_baseline()
        indicators = baseline['bootkit_indicators']

        self.assertIn('common_injection_points', indicators)
        self.assertIn('suspicious_patterns', indicators)
        self.assertIn('bootkit', indicators['suspicious_patterns'])

    # ------------------------------------------------------------------
    # save_baseline / round-trip
    # ------------------------------------------------------------------

    def test_save_baseline_creates_file(self):
        output_path = os.path.join(self.tmp_dir, "baseline.json")
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        analyzer.create_baseline()
        self.assertTrue(analyzer.save_baseline(output_path))
        self.assertTrue(os.path.exists(output_path))

    def test_save_baseline_valid_json(self):
        output_path = os.path.join(self.tmp_dir, "baseline.json")
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        analyzer.create_baseline()
        analyzer.save_baseline(output_path)

        with open(output_path, 'r') as f:
            loaded = json.load(f)

        self.assertIn('metadata', loaded)
        self.assertIn('hashes', loaded)

    def test_save_baseline_bad_path(self):
        analyzer = FirmwareAnalyzer(self.firmware_path)
        analyzer.load_firmware()
        analyzer.create_baseline()
        self.assertFalse(analyzer.save_baseline("/nonexistent/path/baseline.json"))


class TestHardwareFirmwareRecovery(unittest.TestCase):
    """Tests for HardwareFirmwareRecovery (non-hardware, non-root scenarios)."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="pg_hw_test_")
        self.firmware_path = os.path.join(self.tmp_dir, "recovery.bin")
        with open(self.firmware_path, 'wb') as f:
            f.write(make_synthetic_firmware())

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    # ------------------------------------------------------------------
    # Initialisation
    # ------------------------------------------------------------------

    def test_init_with_path(self):
        rec = HardwareFirmwareRecovery(self.firmware_path)
        self.assertEqual(rec.recovery_image_path, Path(self.firmware_path))
        self.assertFalse(rec.verify_only)

    def test_init_without_path(self):
        rec = HardwareFirmwareRecovery()
        self.assertIsNone(rec.recovery_image_path)

    def test_init_verify_only(self):
        rec = HardwareFirmwareRecovery(self.firmware_path, verify_only=True)
        self.assertTrue(rec.verify_only)

    def test_results_initial_structure(self):
        rec = HardwareFirmwareRecovery()
        self.assertIn('timestamp', rec.results)
        self.assertIn('errors', rec.results)
        self.assertIn('warnings', rec.results)
        self.assertFalse(rec.results['recovery_performed'])

    # ------------------------------------------------------------------
    # check_tools (no root needed)
    # ------------------------------------------------------------------

    def test_check_tools_returns_lists(self):
        rec = HardwareFirmwareRecovery()
        missing_critical, missing_optional = rec.check_tools()
        self.assertIsInstance(missing_critical, list)
        self.assertIsInstance(missing_optional, list)

    # ------------------------------------------------------------------
    # _calculate_file_hash
    # ------------------------------------------------------------------

    def test_calculate_file_hash(self):
        rec = HardwareFirmwareRecovery()
        firmware_data = make_synthetic_firmware()
        expected = hashlib.sha256(firmware_data).hexdigest()
        actual = rec._calculate_file_hash(self.firmware_path)
        self.assertEqual(actual, expected)

    # ------------------------------------------------------------------
    # load_firmware_baselines (no baseline present)
    # ------------------------------------------------------------------

    def test_load_baselines_missing_returns_empty(self):
        rec = HardwareFirmwareRecovery()
        baselines = rec.load_firmware_baselines('/nonexistent/baseline.json')
        self.assertEqual(baselines, {})

    def test_load_baselines_valid_file(self):
        baseline_path = os.path.join(self.tmp_dir, "baseline.json")
        baseline_content = {
            'firmware_hashes': {
                'TestBoard': {
                    'hashes': ['abc123']
                }
            }
        }
        with open(baseline_path, 'w') as f:
            json.dump(baseline_content, f)

        rec = HardwareFirmwareRecovery()
        baselines = rec.load_firmware_baselines(baseline_path)
        self.assertIn('TestBoard', baselines)

    # ------------------------------------------------------------------
    # verify_against_baseline
    # ------------------------------------------------------------------

    def test_verify_against_baseline_no_baselines(self):
        rec = HardwareFirmwareRecovery()
        result = rec.verify_against_baseline('deadbeef')
        self.assertEqual(result['status'], 'unknown')
        self.assertFalse(result['verified'])

    def test_verify_against_baseline_known_good(self):
        baseline_path = os.path.join(self.tmp_dir, "baseline.json")
        known_hash = 'aabbcc'
        baseline_content = {
            'firmware_hashes': {
                'general': {'hashes': [known_hash]}
            }
        }
        with open(baseline_path, 'w') as f:
            json.dump(baseline_content, f)

        rec = HardwareFirmwareRecovery()
        # Patch load_firmware_baselines to use our file
        rec.load_firmware_baselines = lambda db=None: {'general': {'hashes': [known_hash]}}
        result = rec.verify_against_baseline(known_hash)
        self.assertEqual(result['status'], 'clean')
        self.assertTrue(result['verified'])

    def test_verify_against_baseline_malicious(self):
        bad_hash = 'deadbeef'
        rec = HardwareFirmwareRecovery()
        rec.load_firmware_baselines = lambda db=None: {'known_malicious': [bad_hash]}
        result = rec.verify_against_baseline(bad_hash)
        self.assertEqual(result['status'], 'malicious')

    def test_verify_against_baseline_suspicious(self):
        rec = HardwareFirmwareRecovery()
        rec.load_firmware_baselines = lambda db=None: {'general': {'hashes': ['otherhash']}}
        result = rec.verify_against_baseline('unknownhash')
        self.assertEqual(result['status'], 'suspicious')

    # ------------------------------------------------------------------
    # verify_recovery_image (file-level checks, no hardware)
    # ------------------------------------------------------------------

    def test_verify_recovery_image_missing_file(self):
        rec = HardwareFirmwareRecovery('/nonexistent/image.bin')
        result = rec.verify_recovery_image()
        self.assertFalse(result)
        self.assertTrue(len(rec.results['errors']) > 0)

    def test_verify_recovery_image_no_path(self):
        rec = HardwareFirmwareRecovery()
        result = rec.verify_recovery_image()
        self.assertFalse(result)

    # ------------------------------------------------------------------
    # save_results
    # ------------------------------------------------------------------

    def test_save_results_creates_file(self):
        output_path = os.path.join(self.tmp_dir, "results.json")
        rec = HardwareFirmwareRecovery()
        rec.save_results(output_path)
        self.assertTrue(os.path.exists(output_path))

    def test_save_results_valid_json(self):
        output_path = os.path.join(self.tmp_dir, "results.json")
        rec = HardwareFirmwareRecovery()
        rec.save_results(output_path)
        with open(output_path, 'r') as f:
            data = json.load(f)
        self.assertIn('timestamp', data)
        self.assertIn('errors', data)


if __name__ == '__main__':
    unittest.main()
