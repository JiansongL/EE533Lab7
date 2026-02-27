#!/usr/bin/env python3
import argparse
import re
from pathlib import Path

OPCODES = {
    "ld": 0x00,
    "st": 0x01,
    "add": 0x02,
    "sub": 0x03,
    "cvta": 0x04,
    "cvt": 0x05,
    "mov": 0x06,
    "mul": 0x07,
    "fma": 0x08,
    "ret": 0x09,
}

REG_RE = re.compile(r"%[a-z]+(\d+)", re.IGNORECASE)
LABEL_RE = re.compile(r"^([A-Za-z_$.][\w$.]*):$")
ENTRY_RE = re.compile(r"^\.visible\s+\.entry\s+([^\(\s]+)")


def strip_comments(line: str) -> str:
    return line.split("//", 1)[0].strip()


def is_instruction(line: str) -> bool:
    if not line:
        return False
    if line in {"{", "}"}:
        return False
    if line.startswith("."):
        return False
    if LABEL_RE.match(line):
        return False
    return True


def canonical_op(op_token: str) -> str:
    op_token = op_token.strip().rstrip(";")
    if op_token.startswith("@"):
        return ""
    return op_token.split(".", 1)[0].lower()


def parse_predicated(line: str):
    line = line.rstrip(";").strip()
    predicate = 0
    if line.startswith("@"):
        parts = line.split(None, 1)
        if len(parts) == 2:
            predicate = 1
            line = parts[1].strip()
    return predicate, line


def split_operands(text: str):
    current = []
    out = []
    bracket_depth = 0
    for ch in text:
        if ch == '[':
            bracket_depth += 1
        elif ch == ']':
            bracket_depth = max(0, bracket_depth - 1)

        if ch == ',' and bracket_depth == 0:
            token = "".join(current).strip()
            if token:
                out.append(token)
            current = []
        else:
            current.append(ch)

    token = "".join(current).strip()
    if token:
        out.append(token)
    return out


def reg_id(token: str) -> int:
    match = REG_RE.search(token)
    if not match:
        return 0
    return int(match.group(1)) & 0x0F


def imm8(token: str, labels: dict) -> int:
    token = token.strip().rstrip(",")
    if token in labels:
        return labels[token] & 0xFF

    token = token.strip("[]")
    try:
        if token.startswith("0x") or token.startswith("0X"):
            return int(token, 16) & 0xFF
        if token.startswith("0f") and len(token) > 2:
            return int(token[2:], 16) & 0xFF
        return int(float(token)) & 0xFF
    except Exception:
        return 0


def encode_line(line: str, labels: dict):
    predicate, line = parse_predicated(line)
    if not line:
        return None

    parts = line.split(None, 1)
    if not parts:
        return None

    op_token = parts[0]
    op_base = canonical_op(op_token)
    if not op_base:
        return None

    opcode = OPCODES.get(op_base)
    if opcode is None:
        return None

    operands = []
    if len(parts) > 1:
        operands = split_operands(parts[1].rstrip(";"))

    rd = reg_id(operands[0]) if len(operands) > 0 else 0
    rs1 = reg_id(operands[1]) if len(operands) > 1 else 0
    rs2 = reg_id(operands[2]) if len(operands) > 2 else 0

    if op_base == "st":
        rd = reg_id(operands[1]) if len(operands) > 1 else 0
        rs1 = reg_id(operands[0]) if len(operands) > 0 else 0
        rs2 = 0
    elif op_base == "ret":
        rd = 0
        rs1 = 0
        rs2 = 0
    
    # format for encoding:
    # [31:26] opcode
    # [25:22] rd
    # [21:18] rs1
    # [17:14] rs2
    encoded = (
        ((opcode & 0x3F) << 26)
        | ((rd & 0x0F) << 22)
        | ((rs1 & 0x0F) << 18)
        | ((rs2 & 0x0F) << 14)
    )
    return encoded, op_base, operands


def collect_labels(lines):
    labels = {}
    pc = 0
    for line in lines:
        clean = strip_comments(line)
        label = LABEL_RE.match(clean)
        if label:
            labels[label.group(1)] = pc
            continue
        if is_instruction(clean):
            pc += 1
    return labels


def translate_ptx_to_hex(ptx_text: str):
    lines = ptx_text.splitlines()
    labels = collect_labels(lines)

    out = []
    pc = 0
    current_entry = None

    for raw in lines:
        clean = strip_comments(raw)
        if not clean:
            continue

        entry_match = ENTRY_RE.match(clean)
        if entry_match:
            current_entry = entry_match.group(1)
            out.append(f"# entry {current_entry}")
            continue

        if not is_instruction(clean):
            continue

        encoded = encode_line(clean, labels)
        if encoded is None:
            continue

        word, op_base, _ = encoded
        out.append(f"{word:08X}    # pc={pc:04d} op={op_base} :: {clean}")
        pc += 1

    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description="Translate PTX assembly to custom GPU hex opcodes.")
    parser.add_argument("input_ptx", type=Path, help="Path to .ptx file")
    parser.add_argument("-o", "--output", type=Path, default=Path("gpu_program.hex"), help="Output .hex file")
    args = parser.parse_args()

    ptx_text = args.input_ptx.read_text(encoding="utf-8")
    hex_text = translate_ptx_to_hex(ptx_text)
    args.output.write_text(hex_text, encoding="utf-8")

    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
