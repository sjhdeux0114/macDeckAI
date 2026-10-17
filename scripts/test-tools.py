#!/usr/bin/env python3
import gzip
import importlib.util
from pathlib import Path
import struct
import unittest


def module(filename):
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_"), Path(__file__).with_name(filename + ".py"))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


kernel = module("extract-kernel")
audit = module("audit-source")


class KernelTests(unittest.TestCase):
    def test_raw_image(self):
        data = bytearray(128)
        data[56:60] = b"ARMd"
        self.assertEqual(kernel.extract(bytes(data)), data)

    def test_zboot(self):
        data = bytearray(128)
        data[56:60] = b"ARMd"
        payload = gzip.compress(data)
        header = bytearray(64)
        header[4:8] = b"zimg"
        header[24:28] = b"gzip"
        struct.pack_into("<II", header, 8, 64, len(payload))
        self.assertEqual(kernel.extract(bytes(header) + payload), data)
        with self.assertRaises(ValueError):
            kernel.extract(bytes(header) + payload[:-8])

    def test_non_kernel_payload(self):
        payload = gzip.compress(b"not a kernel")
        header = bytearray(64)
        header[4:8], header[24:28] = b"zimg", b"gzip"
        struct.pack_into("<II", header, 8, 64, len(payload))
        with self.assertRaises(ValueError):
            kernel.extract(bytes(header) + payload)


class ELFTests(unittest.TestCase):
    def test_non_elf(self):
        self.assertIsNone(audit.elf_info(b"MZ" + b"\0" * 80))

    def test_architectures_and_byte_orders(self):
        for bits in (1, 2):
            for encoding, order in ((1, "<"), (2, ">")):
                data = bytearray(64)
                data[:6] = b"\x7fELF" + bytes((bits, encoding))
                struct.pack_into(order + "H", data, 18, 183)
                info = audit.elf_info(data)
                self.assertEqual(info["machine"], "aarch64")
                self.assertEqual(info["bits"], 64 if bits == 2 else 32)

    def test_dynamic_dependencies(self):
        data = bytearray(512)
        data[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<HHIQQQIHHHHHH", data, 16, 3, 183, 1, 0, 64, 0, 0, 64, 56, 2, 0, 0, 0)
        struct.pack_into("<IIQQQQQQ", data, 64, 1, 0, 0, 0x1000, 0, 512, 512, 0)
        struct.pack_into("<IIQQQQQQ", data, 120, 2, 0, 192, 0x10c0, 0, 48, 48, 0)
        struct.pack_into("<qQqQqQ", data, 192, 5, 0x112c, 1, 1, 0, 0)
        data[300:309] = b"\0libc.so\0"
        self.assertEqual(audit.elf_info(data)["needed"], ["libc.so"])


unittest.main()
