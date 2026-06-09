# AXI-4 Slave RTL Bug Summary
**Date: June 8, 2026**

---

## Overview
This document outlines all bugs introduced in the `buggy-with-error-response` branch of the axi4-slave-rtl repository for student practice and verification exercises.

---

## Bug #1: FIXED Burst Type Write Error

### **Description**
Write data is incorrectly captured in memory when using FIXED burst type with specific address and size conditions.

### **Trigger Conditions (ALL must be true)**
- `AWBURST = 2'b00` (FIXED burst)
- `AWADDR > 100` (address above 100)
- `AWSIZE > 5` (burst size greater than 5)

### **Location**
Lines 167-171 in `axi4_slave.v` (Write data logic)

### **Implementation Details**
```verilog
if (wr_burst == 2'b00 && wr_addr > 100 && wr_size > 5) begin
    write_addr = (wr_addr_curr >> 1);  // Wrong shift (>>1 instead of >>2)
end else begin
    write_addr = wr_addr_curr[ADDR_WIDTH-1:2];  // Normal: correct shift
end
```

### **Root Cause**
Address shifted by 1 bit instead of 2 bits during byte-to-word conversion, causing data to be written to the wrong memory location.

### **Impact**
- Data corruption: write data captured at wrong memory address
- Address calculated as `addr/2` instead of `addr/4`
- Overlaps with adjacent memory locations

### **Normal Cases (Unaffected)**
- ✓ INCR burst type writes
- ✓ WRAP burst type writes
- ✓ Writes with `AWADDR ≤ 100`
- ✓ Writes with `AWSIZE ≤ 5`
- ✓ Any combination not matching all three trigger conditions

### **Test Scenario - Works**
```
Write Request:
  AWBURST = FIXED
  AWADDR = 50
  AWSIZE = 3
  WDATA = 0x12345678

Expected Result: ✓ Data written to memory[50>>2 = 12]
Actual Result: ✓ Correct (conditions not met)
```

### **Test Scenario - Fails**
```
Write Request:
  AWBURST = FIXED
  AWADDR = 120
  AWSIZE = 6
  WDATA = 0x12345678

Expected Result: ✓ Data written to memory[120>>2 = 30]
Actual Result: ✗ Data written to memory[120>>1 = 60] (WRONG!)
```

---

## Bug #2: FIXED Burst Read — rvalid Drop with Guaranteed Skip (Read Data Loss)

### **Description**
During FIXED read bursts targeting high addresses, the slave intermittently de-asserts `rvalid` for a beat and advances the internal read counters regardless. This causes the master to miss that beat permanently (information loss).

### **Trigger Conditions (ALL must be true)**
- `ARBURST = 2'b00` (FIXED burst)
- `rd_addr_curr > 32'd1000` (current read address above 1000)
- PRNG condition (pseudo-random LFSR bit) is set during the beat

### **Location**
Read data channel logic in `axi4_slave.v` (read-data handler block)

### **Implementation Details (behavioral)**
- The slave may set `rvalid = 0` for a beat while still presenting `rdata` on the bus.
- Despite `rvalid` being de-asserted, the slave advances `rd_addr_curr` and `rd_beat_count` as if the beat was accepted.
- The master never samples that beat (it is lost).

### **Root Cause**
A PRNG-driven condition forces `rvalid` low but still increments the internal read counters. AXI protocol requires advancing the beat only when both `rvalid` and `rready` are sampled; advancing while `rvalid` is low results in a dropped beat.

### **Impact**
- Information loss: one or more read beats can be permanently missed by the master
- Misaligned `rlast` timing relative to sampled beats
- Hard-to-detect intermittent failures in higher-level protocols that depend on contiguous data

### **Deterministic Reproduction**
- Initialize or force the LFSR seed bit used by the PRNG so the condition triggers predictably in simulation.
- Issue a FIXED read burst with `ARADDR > 1000` and `ARLEN >= 1`.
- Observe a cycle where `rvalid == 0` and the next presented beat corresponds to the subsequent address (skipped beat).

---

## Bug #3: INCR Burst — Periodic Non-Increment (Read & Write)

### **Description**
For INCR bursts at high addresses, the slave intentionally does not increment the transfer address for one beat after every five increments. This applies to both read and write flows and causes replayed data or repeated writes every sixth beat.

### **Trigger Conditions (ALL must be true)**
- `AWBURST/ARBURST = 2'b01` (INCR burst)
- `wr_addr_curr` or `rd_addr_curr` > 32'd2000 (current address above 2000)
- Beat count reaches the 5th increment (the next beat is suppressed)

### **Location**
Write and read beat update logic in `axi4_slave.v` (write-beat and read-data handler blocks)

### **Implementation Details (behavioral)**
- Counters (`wr_incr_count`, `rd_incr_count`) track increments modulo 5.
- After five increments, a `*_suppress_inc` flag causes the next beat to hold the address (no increment) for exactly one beat, then counting resumes.
- For writes: two consecutive write beats may target the same memory index for one beat following every five increments.
- For reads: the slave may present the same `rdata` for two beats in a row (address held for one beat), shifting subsequent beat alignment.

### **Root Cause**
Deliberate logic inserted to skip the increment under specific conditions; this violates expected INCR semantics where the address should increment every beat (unless FIXED).

### **Impact**
- Replayed data for one beat or repeated memory writes to the same address every sixth beat
- Misalignment between expected data sequence and actual data received by the master
- Potential higher-level protocol/state corruption when consecutive beats are assumed unique

### **Test Scenario**
```
Read Request:
  ARBURST = INCR
  ARADDR = 0x00000800 (2048 > 2000)
  ARLEN  = 11 (12 beats)

Observed behavior:
  Beats 0..4: normal increments
  Beat 5: address held (same data/address as beat 4)
  Beats 6..10: increments resume
  Beat 11: may be affected if count wraps
```

---

## Bug #4: WRAP Burst — Alternating Off-by-One Wrap Target (Read & Write)

### **Description**
For WRAP bursts the slave alternates the wrap target: every second wrap event computes a wrap target that is one beat earlier than the correct target, causing an off-by-one address at those wrap boundaries.

### **Trigger Conditions (ALL must be true)**
- `AWBURST/ARBURST = 2'b10` (WRAP burst)
- Burst spans a wrap boundary (wrap event occurs)

### **Location**
WRAP handling logic in `axi4_slave.v` within the write-beat and read-data update paths

### **Implementation Details (behavioral)**
- Two toggle flags (`wr_wrap_toggle`, `rd_wrap_toggle`) flip each time a wrap event is detected for write and read respectively.
- When the toggle is set, the computed wrap target is adjusted by subtracting one beat (addr_offset) from the expected wrap address for that wrap.
- Toggles ensure the off-by-one occurs on every second wrap (alternating behavior).

### **Root Cause**
Deliberate insertion of an alternating adjustment to the wrap target calculation, causing intermittent off-by-one wrap behavior.

### **Impact**
- Addresses at affected wrap events are one beat earlier than expected.
- For reads: `rdata` sequence or `rlast` position may be shifted on alternate wrap events.
- For writes: memory writes at wraps may target the wrong index on alternate events.

### **Test Scenario**
```
Generate a WRAP read or write burst that crosses wrap boundary multiple times.
Observe the sequence of addresses around each wrap — every second wrap should land one beat earlier than the expected wrap target.
```

---

## Memory Initialization

### **Description**
All memory addresses are prefilled with the `0xabab` pattern.

### **Implementation Details (Lines 106-116)**
```verilog
case (DATA_WIDTH)
    8:  memory[i] = 8'hAB;
    16: memory[i] = 16'hABAB;
    32: memory[i] = 32'hABABABAB;
    64: memory[i] = 64'hABABABABABABABAB;
    128: memory[i] = 128'hABABABABABABABABABABABABABABABAB;
    default: memory[i] = {(DATA_WIDTH/16){16'hABAB}};
endcase
```

### **Purpose**
- Provides known initial state for memory
- Helps detect uninitialized or missing read data
- Useful for verification: any read should return at least `0xabab` pattern

### **Effect**
- Read operations return prefilled data: `0xABAB...` (pattern depends on DATA_WIDTH)
- Useful for detecting if reads are working before writes

---

## Repository Structure

### **Branches**

{