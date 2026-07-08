# AXI-4 Slave RTL Bug Summary
**Date: June 8, 2026**

---

## Overview
This document outlines all bugs introduced in the `buggy-with-error-response` branch of the axi4-slave-rtl repository for student practice and verification exercises.

**STATUS: ALL BUGS FIXED ✅**

---

## Bug #1: FIXED Burst Type Write Error

### **Description**
Write data is incorrectly captured in memory when using FIXED burst type with specific address and size conditions.

### **Trigger Conditions (ALL must be true)**
- `AWBURST = 2'b00` (FIXED burst)
- `AWADDR > 100` (address above 100)
- `AWSIZE > 5` (burst size greater than 5)

### **Location**
Lines 187-188 in `axi4_slave.v` (Write data logic)

### **Implementation Details (BUGGY CODE)**
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

### **FIX APPLIED ✅**
**Line 188**: Changed shift operator from `>> 1` to `>> 2`
```verilog
if (wr_burst == 2'b00 && wr_addr > 100 && wr_size > 5) begin
    write_addr = (wr_addr_curr >> 2);  // FIXED: Correct shift (>>2)
end else begin
    write_addr = wr_addr_curr[ADDR_WIDTH-1:2];
end
```

**Result**: Data now written to correct memory location (addr/4) for all FIXED burst conditions.

---

## Bug #2: FIXED Burst Read — rvalid Drop with Guaranteed Skip (Read Data Loss)

### **Description**
During FIXED read bursts targeting high addresses, the slave intermittently de-asserts `rvalid` for a beat and advances the internal read counters regardless. This causes the master to miss that beat.

### **Trigger Conditions (ALL must be true)**
- `ARBURST = 2'b00` (FIXED burst)
- `rd_addr_curr > 32'd1000` (current read address above 1000)
- PRNG condition (pseudo-random LFSR bit) is set during the beat

### **Location**
Lines 313-345 in `axi4_slave.v` (read-data handler block)

### **Implementation Details (BUGGY CODE)**
```verilog
if (rd_burst == 2'b00 && rd_addr_curr > 32'd1000 && rnd_lfsr[3]) begin
    rvalid <= 1'b0;  // WRONG: De-asserts rvalid
    rid <= rd_id;
    rdata <= memory[rd_addr_curr[ADDR_WIDTH-1:2]];
    rresp <= 2'b00;
    
    // ... still advances counters even though rvalid is 0
    if (rd_beat_count < rd_len) begin
        rd_addr_curr <= calc_next_addr(...);
        rd_beat_count <= rd_beat_count + 1'b1;  // Counter advances!
    end
end else begin
    rvalid <= 1'b1;  // Normal path
    // ...
end
```

### **Root Cause**
A PRNG-driven condition forces `rvalid` low but still increments the internal read counters. AXI protocol requires advancing the beat only when both `rvalid` and `rready` are sampled; advancing when `rvalid` is de-asserted violates the protocol.

### **Impact**
- Information loss: one or more read beats can be permanently missed by the master
- Misaligned `rlast` timing relative to sampled beats
- Hard-to-detect intermittent failures in higher-level protocols that depend on contiguous data

### **Deterministic Reproduction**
- Initialize or force the LFSR seed bit used by the PRNG so the condition triggers predictably in simulation.
- Issue a FIXED read burst with `ARADDR > 1000` and `ARLEN >= 1`.
- Observe a cycle where `rvalid == 0` and the next presented beat corresponds to the subsequent address (skipped beat).

### **FIX APPLIED ✅**
**Lines 313-345**: Removed PRNG-based rvalid drop condition. Now always asserts rvalid when presenting read data.

**Before:**
```verilog
if (rd_burst == 2'b00 && rd_addr_curr > 32'd1000 && rnd_lfsr[3]) begin
    rvalid <= 1'b0;  // WRONG
    // ... present data and advance counters
end else begin
    rvalid <= 1'b1;
    // ...
end
```

**After:**
```verilog
// Removed the PRNG condition entirely
rvalid <= 1'b1;  // CORRECT: Always assert when presenting data
rid <= rd_id;
rdata <= memory[rd_addr_curr[ADDR_WIDTH-1:2]];
rresp <= 2'b00;

if (rvalid && rready) begin
    if (rd_beat_count < rd_len) begin
        rd_addr_curr <= calc_next_addr(...);
        rd_beat_count <= rd_beat_count + 1'b1;  // Only advances when sampled
    end
end
```

**Result**: Read data is no longer lost. All beats are properly presented and sampled according to AXI protocol.

---

## Bug #3: INCR Burst — Periodic Non-Increment (Read & Write)

### **Description**
For INCR bursts at high addresses, the slave intentionally does not increment the transfer address for one beat after every five increments. This applies to both read and write flows and causes replayed data.

### **Trigger Conditions (ALL must be true)**
- `AWBURST/ARBURST = 2'b01` (INCR burst)
- `wr_addr_curr` or `rd_addr_curr` > 32'd2000 (current address above 2000)
- Beat count reaches the 5th increment (the next beat is suppressed)

### **Location**
Lines 200-213 (Write) and 360-373 (Read) in `axi4_slave.v` (beat update logic)

### **Implementation Details (BUGGY CODE - WRITE PATH)**
```verilog
if (wr_burst == 2'b01 && wr_addr_curr > 32'd2000) begin
    if (wr_suppress_inc) begin
        wr_suppress_inc <= 1'b0;
        // do not increment this beat - ADDRESS HELD
    end else begin
        wr_addr_curr <= calc_next_addr(...);
        if (wr_incr_count == 3'd4) begin
            wr_suppress_inc <= 1'b1;  // Flag set to suppress next increment
            wr_incr_count <= 3'b0;
        end else begin
            wr_incr_count <= wr_incr_count + 1'b1;
        end
    end
    wr_beat_count <= wr_beat_count + 1'b1;
end
```

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

### **FIX APPLIED ✅**
**Lines 200-213 (Write) and 360-373 (Read)**: Removed address increment suppression logic and related counters.

**Before:**
```verilog
if (wr_burst == 2'b01 && wr_addr_curr > 32'd2000) begin
    if (wr_suppress_inc) begin
        wr_suppress_inc <= 1'b0;
        // do not increment
    end else begin
        wr_addr_curr <= calc_next_addr(...);
        if (wr_incr_count == 3'd4) begin
            wr_suppress_inc <= 1'b1;
            wr_incr_count <= 3'b0;
        end else begin
            wr_incr_count <= wr_incr_count + 1'b1;
        end
    end
    wr_beat_count <= wr_beat_count + 1'b1;
end else if (wr_burst == 2'b10) begin
    // wrap handling
end else begin
    wr_addr_curr <= calc_next_addr(...);
    wr_beat_count <= wr_beat_count + 1'b1;
end
```

**After:**
```verilog
// Simplified and fixed - always increment for INCR bursts
wr_addr_curr <= calc_next_addr(wr_addr_curr, wr_size, wr_burst, wr_len);

if (wr_burst == 2'b10) begin
    // wrap handling
end

wr_beat_count <= wr_beat_count + 1'b1;
```

**Also removed initialization of these unused registers:**
- `wr_incr_count` (line 77)
- `wr_suppress_inc` (line 78)
- `rd_incr_count` (line 79)
- `rd_suppress_inc` (line 80)

**Result**: Address now increments on every beat for INCR bursts. No more replayed data or address hold cycles.

---

## Bug #4: WRAP Burst — Alternating Off-by-One Wrap Target (Read & Write)

### **Description**
For WRAP bursts the slave alternates the wrap target: every second wrap event computes a wrap target that is one beat earlier than the correct target, causing an off-by-one address at those wrap events.

### **Trigger Conditions (ALL must be true)**
- `AWBURST/ARBURST = 2'b10` (WRAP burst)
- Burst spans a wrap boundary (wrap event occurs)

### **Location**
Lines 214-232 (Write) and 374-388 (Read) in `axi4_slave.v` (wrap handling logic)

### **Implementation Details (BUGGY CODE - WRITE PATH)**
```verilog
else if (wr_burst == 2'b10) begin
    reg [ADDR_WIDTH-1:0] addr_offset;
    reg [ADDR_WIDTH-1:0] burst_mask;
    reg [ADDR_WIDTH-1:0] next_addr;
    addr_offset = 1 << wr_size;
    burst_mask = ((wr_len + 1) << wr_size) - 1;
    next_addr = calc_next_addr(wr_addr_curr, wr_size, wr_burst, wr_len);

    // detect wrap event by checking lower-field rollover
    if ( ((wr_addr_curr + addr_offset) & burst_mask) < (wr_addr_curr & burst_mask) ) begin
        if (wr_wrap_toggle) begin
            // adjust to one beat before expected wrap target
            next_addr = next_addr - addr_offset;  // OFF-BY-ONE ERROR
        end
        wr_wrap_toggle <= ~wr_wrap_toggle;  // Toggle for next wrap
    end

    wr_addr_curr <= next_addr;
    wr_beat_count <= wr_beat_count + 1'b1;
end
```

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

### **FIX APPLIED ✅**
**Lines 214-232 (Write) and 374-388 (Read)**: Removed wrap toggle-based off-by-one adjustment. Also removed the toggle flags.

**Before:**
```verilog
else if (wr_burst == 2'b10) begin
    // ... calculate next_addr ...
    if (wrap event detected) begin
        if (wr_wrap_toggle) begin
            next_addr = next_addr - addr_offset;  // WRONG: off-by-one on alternate wraps
        end
        wr_wrap_toggle <= ~wr_wrap_toggle;
    end
    wr_addr_curr <= next_addr;
    wr_beat_count <= wr_beat_count + 1'b1;
end
```

**After:**
```verilog
if (wr_burst == 2'b10) begin
    reg [ADDR_WIDTH-1:0] addr_offset;
    reg [ADDR_WIDTH-1:0] burst_mask;
    reg [ADDR_WIDTH-1:0] next_addr;
    addr_offset = 1 << wr_size;
    burst_mask = ((wr_len + 1) << wr_size) - 1;
    next_addr = calc_next_addr(wr_addr_curr, wr_size, wr_burst, wr_len);
    wr_addr_curr <= next_addr;  // No off-by-one adjustment
end

wr_beat_count <= wr_beat_count + 1'b1;
```

**Also removed these unused registers:**
- `wr_wrap_toggle` (line 83)
- `rd_wrap_toggle` (line 84)

**Result**: Wrap target calculations are now consistent and correct on every wrap event. No more off-by-one errors on alternate wraps.

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

- **main**: Clean, bug-free reference implementation
- **buggy-with-error-response**: Contains 4 intentional bugs for training/verification (NOW FIXED ✅)

---

## Summary of Changes

**Commit SHA**: `f44597ad61ec055a9b7fb3fd132e69ab5428f7bd`

All 4 bugs have been fixed:
- ✅ Bug #1: FIXED burst address shift corrected (>> 2)
- ✅ Bug #2: PRNG-based rvalid drop removed
- ✅ Bug #3: INCR burst address increment suppression removed
- ✅ Bug #4: WRAP burst toggle-based off-by-one adjustment removed

All fixes maintain compliance with AXI-4 protocol specifications.
