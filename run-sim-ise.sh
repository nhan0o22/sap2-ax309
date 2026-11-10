#!/usr/bin/env bash
# Run from an ISE 14.7 command-line environment (settings64.sh already sourced).
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p sim-results
for top in memory_tb keys_tb top_tb; do
    case "$top" in
        memory_tb) sources=(memory_tb.v memory.v) ;;
        keys_tb) sources=(keys_tb.v ax309_io.v) ;;
        top_tb) sources=(top_tb.v top.v ax309_io.v memory.v register.v pc.v flags.v alu.v) ;;
    esac
    prj="sim-results/${top}.prj"
    printf 'verilog work "%s"\n' "${sources[@]}" > "$prj"
    printf 'run all\nquit\n' > "sim-results/${top}.tcl"
    fuse -prj "$prj" -o "sim-results/${top}_isim" "work.${top}"
    "./sim-results/${top}_isim" -tclbatch "sim-results/${top}.tcl" | tee "sim-results/${top}-ise.log"
    if grep -q '^FAIL:' "sim-results/${top}-ise.log" || ! grep -q '^PASS:' "sim-results/${top}-ise.log"; then
        exit 1
    fi
done
