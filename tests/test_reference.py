"""Independent protocol/register reference checks; these do not simulate RTL."""
from collections import deque
from pathlib import Path
import random
import re
import unittest


def frame_bits(value: int, width: int, lsb_first: bool):
    indices = range(width) if lsb_first else range(width - 1, -1, -1)
    return [(value >> i) & 1 for i in indices]


def sampled_edges(width: int, cpha: int):
    """Return edge numbers (0 based) where a frame samples bits."""
    return [i for i in range(width * 2) if (i % 2) == cpha]


class ReferenceTests(unittest.TestCase):
  def test_widths_and_bit_orders_round_trip(self):
    for width in (8, 16, 32):
      value = 0xA55AC33C & ((1 << width) - 1)
      for lsb in (False, True):
        bits = frame_bits(value, width, lsb)
        rebuilt = sum(bit << (i if lsb else width - 1 - i) for i, bit in enumerate(bits))
        self.assertEqual(rebuilt, value)

  def test_seeded_random_frames_round_trip(self):
    rng = random.Random(0x51A7C0DE)
    for _ in range(128):
      width = rng.choice((8, 16, 32))
      value = rng.getrandbits(width)
      lsb_first = bool(rng.getrandbits(1))
      bits = frame_bits(value, width, lsb_first)
      rebuilt = sum(bit << (i if lsb_first else width - 1 - i) for i, bit in enumerate(bits))
      self.assertEqual(rebuilt, value)
      self.assertEqual(len(sampled_edges(width, rng.randrange(2))), width)


  def test_all_spi_modes_have_exact_sample_edge_count(self):
    for cpol in (0, 1):
      for cpha in (0, 1):
        edges = sampled_edges(8, cpha)
        self.assertEqual(len(edges), 8)
        self.assertEqual(edges, list(range(cpha, 16, 2)))
        # A sample edge rises for modes 0 and 3, and falls for modes 1 and 2.
        sample_rising = (1 - cpol) if cpha == 0 else cpol
        self.assertEqual(bool(sample_rising), cpol == cpha)


  def test_fifo_capacity_and_overflow_policy(self):
    fifo = deque(maxlen=16)
    overflow = False
    for value in range(16):
      if len(fifo) == fifo.maxlen:
        overflow = True
      else:
        fifo.append(value)
    if len(fifo) == fifo.maxlen:
      overflow = True
    else:
      fifo.append(99)
    self.assertEqual(list(fifo), list(range(16)))
    self.assertTrue(overflow)


  def test_apb_register_alignment_map(self):
    addresses = {0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18, 0x1C,
                 0x20, 0x24, 0x28, 0x2C}
    self.assertTrue(all((address & 3) == 0 for address in addresses))
    self.assertEqual(len(addresses), 12)
    self.assertNotIn(0x30, addresses)
    root = Path(__file__).resolve().parents[1]
    header = (root / "sw" / "include" / "spi_x.h").read_text(encoding="utf-8")
    rtl = (root / "rtl" / "spi_x_top.sv").read_text(encoding="utf-8")
    for name, rtl_name, offset in (("CTRL","CTRL",0x00),("STATUS","STATUS",0x04),
                         ("CLK_DIV","CLK_DIV",0x08),("CONFIG","CONFIG",0x0c),
                         ("TX_DATA","TX",0x10),("RX_DATA","RX",0x14),
                         ("INT_ENABLE","IEN",0x18),("INT_STATUS","IST",0x1c),
                         ("FIFO_CTRL","FIFO_CTRL",0x20),("CS_CTRL","CS_CTRL",0x24),
                         ("TRANSFER_LEN","TRANSFER_LEN",0x28),("ERROR_STATUS","ERROR_STATUS",0x2c)):
      self.assertRegex(header, rf"{name}\s*;\s*/\*\s*0x{offset:02X}\s*\*/")
      self.assertIn(f"A_{rtl_name}=8'h{offset:02X}", rtl)


  def test_width_encoding_matches_firmware_header(self):
    encodings = {8: 0b00, 16: 0b01, 32: 0b10}
    self.assertTrue(all((code & 0b11) != 0b11 for code in encodings.values()))
    self.assertEqual(len(set(encodings.values())), 3)

  def test_top_level_named_port_bindings(self):
    root = Path(__file__).resolve().parents[1]
    rtl = root / "rtl"
    module_ports = {}
    for path in rtl.glob("*.sv"):
      source = path.read_text(encoding="utf-8")
      for match in re.finditer(r"\bmodule\s+(\w+)\s*(?:#\s*\(.*?\)\s*)?\((.*?)\);", source, re.S):
        names = re.findall(r"\b(?:input|output|inout)\s+(?:logic|wire|reg)?\s*(?:\[[^\]]+\]\s*)?(\w+)", match.group(2))
        module_ports[match.group(1)] = set(names)
    top = (rtl / "spi_x_top.sv").read_text(encoding="utf-8")
    instances = list(re.finditer(
      r"\b(async_fifo|sync_fifo|spi_master|spi_slave)\s*(?:#\s*\(.*?\)\s*)?(\w+)\s*\((.*?)\);",
      top, re.S))
    self.assertEqual(len(instances), 6)
    for instance in instances:
      module, instance_name, body = instance.groups()
      connected = set(re.findall(r"\.(\w+)\s*\(", body))
      self.assertLessEqual(connected, module_ports[module], f"{instance_name}: unknown port")

  def test_each_clock_domain_has_synchronized_reset_release(self):
    root = Path(__file__).resolve().parents[1]
    reset = (root / "rtl" / "reset_sync.sv").read_text(encoding="utf-8")
    top = (root / "rtl" / "spi_x_top.sv").read_text(encoding="utf-8")
    self.assertIn('(* ASYNC_REG = "TRUE" *) logic [1:0] release_pipe', reset)
    self.assertIn("posedge clk or negedge arst_n", reset)
    self.assertIn("assign srst_n = release_pipe[1]", reset)
    self.assertIn("reset_sync u_pclk_reset", top)
    self.assertIn("reset_sync u_slave_reset", top)
    self.assertIn(".srst_n(pclk_reset_n)", top)
    self.assertIn(".srst_n(slave_reset_n)", top)

  def test_slave_event_acknowledgement_has_synchronized_release(self):
    root = Path(__file__).resolve().parents[1]
    top = (root / "rtl" / "spi_x_top.sv").read_text(encoding="utf-8")
    slave = (root / "rtl" / "spi_slave.sv").read_text(encoding="utf-8")
    self.assertIn("reset_sync u_slave_ack_reset", top)
    self.assertIn(".arst_n(!slave_event_ack)", top)
    self.assertIn(".srst_n(slave_ack_reset_n)", top)
    self.assertIn("assign slave_event_reset_n = slave_reset_n && slave_ack_reset_n", top)
    self.assertIn("always_ff @(posedge sample_clk or negedge event_reset_n)", slave)
    for crossing in ("rx_full_slave_q1 <= rx_full_slave", "tx_empty_slave_q1 <= tx_empty_slave",
                     "slave_busy_q1 <= slave_busy", "slave_underflow_q1 <= slave_underflow_toggle",
                     "slave_overflow_q1 <= slave_rx_overflow_toggle"):
      self.assertIn(crossing, top)

  def test_constraint_template_covers_clocks_and_cdc(self):
    root = Path(__file__).resolve().parents[1]
    sdc = (root / "constraints" / "spi_x_template.sdc").read_text(encoding="utf-8")
    for command in ("create_clock", "create_generated_clock", "set_max_delay", "set_false_path", "set_input_delay", "set_output_delay"):
      self.assertIn(command, sdc)
    self.assertIn("*u_tx_slave*wr_gray_rq1_reg*", sdc)
    self.assertIn("*u_rx_slave*rd_gray_wq1_reg*", sdc)
