"""Inspect key outcomes in the VCD emitted by the integrated testbench."""
from pathlib import Path
import sys


def inspect(path: Path) -> dict[str, int]:
    lines = path.read_text(encoding="ascii", errors="replace").splitlines()
    scope: list[str] = []
    top_ids: dict[str, str] = {}
    widths: dict[str, int] = {}
    end_header = 0
    for pos, line in enumerate(lines):
        line = line.strip()
        parts = line.split()
        if line.startswith("$scope"):
            scope.append(parts[2])
        elif line.startswith("$upscope"):
            if scope:
                scope.pop()
        elif line.startswith("$var") and scope in (["tb_spi_x"], ["TOP", "tb_spi_x"]):
            widths[parts[3]] = int(parts[2])
            top_ids[parts[4]] = parts[3]
        elif line.startswith("$enddefinitions"):
            end_header = pos + 1
            break

    required = {"spi_cs_out_n", "spi_sclk_out", "spi_miso_oe", "pslverr", "tx"}
    missing = required - top_ids.keys()
    if missing:
        raise AssertionError(f"VCD is missing top-level signals: {sorted(missing)}")

    ids = {name: top_ids[name] for name in required}
    values: dict[str, str] = {}
    cs_pulses = 0
    sclk_edges_while_cs = 0
    miso_enable_high = 0
    pslverr_high = 0
    rx_words: set[int] = set()

    for line in lines[end_header:]:
        line = line.strip()
        if not line or line[0] in "$#":
            continue
        if line[0] in "bBrR":
            value, ident = line.split()[:2]
            value = value[1:].lower()
        else:
            value, ident = line[0].lower(), line[1:]
        if ident not in ids.values():
            continue
        old = values.get(ident)
        values[ident] = value
        if ident == ids["spi_cs_out_n"] and old == "1111" and value != "1111":
            cs_pulses += 1
        elif ident == ids["spi_sclk_out"] and old is not None and old != value:
            if values.get(ids["spi_cs_out_n"]) not in (None, "1111"):
                sclk_edges_while_cs += 1
        elif ident == ids["spi_miso_oe"] and value == "1":
            miso_enable_high += 1
        elif ident == ids["pslverr"] and old != "1" and value == "1":
            pslverr_high += 1
        elif ident == ids["tx"] and value and all(c in "01" for c in value):
            rx_words.add(int(value, 2))

    result = {
        "master_cs_frames": cs_pulses,
        "master_sclk_edges_under_cs": sclk_edges_while_cs,
        "slave_miso_enable_assertions": miso_enable_high,
        "apb_error_assertions": pslverr_high,
        "observed_apb_rx_expected_frame": int(0xDA in rx_words),
    }
    if result["master_cs_frames"] != 66:
        raise AssertionError(f"expected 66 master chip-select transactions, observed {result['master_cs_frames']}")
    if result["master_sclk_edges_under_cs"] < 1300:
        raise AssertionError(f"too few SCLK transitions under CS: {result['master_sclk_edges_under_cs']}")
    if result["slave_miso_enable_assertions"] == 0:
        raise AssertionError("slave MISO output enable was never asserted")
    if result["apb_error_assertions"] != 1:
        raise AssertionError(f"expected one APB error pulse, observed {result['apb_error_assertions']}")
    if result["observed_apb_rx_expected_frame"] != 1:
        raise AssertionError("expected slave RX value 0xDA was not observed on APB")
    return result


if __name__ == "__main__":
    waveform = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("spi_x.vcd")
    for key, value in inspect(waveform).items():
        print(f"PASS {key}: {value}")
