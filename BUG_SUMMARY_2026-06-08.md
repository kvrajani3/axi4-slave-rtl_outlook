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
    write_addr = (wr_addr_curr >> 1);  // BUG: Wrong shift (>>1 instead of >>2)
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

## Memory Initialization

### **Description**
All memory addresses are prefilled with the `0xabab` pattern.

### **Implementation Details (Lines 88-93)**
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

| Branch | Status | Purpose |
|--------|--------|---------|
| `main` | ✅ Clean | Original working code - reference implementation |
| `buggy-with-error-response` | ❌ Buggy | Code with intentional bugs for student practice |

### **File Location**
- Repository: `axi4-slave-rtl`
- Main file: `axi4_slave.v`
- Module parameters:
  - `DATA_WIDTH` = 32 bits (default)
  - `ADDR_WIDTH` = 32 bits (default)
  - `ID_WIDTH` = 12 bits (default)
  - `MEM_SIZE` = 4096 words (4KB memory)

---

## Working Features (Unaffected)

### **Read Channel** ✓
- All read transactions work correctly
- Supports all burst types (FIXED, INCR, WRAP)
- Proper RLAST assertion on final beat
- Returns OKAY response (2'b00) for all reads
- Multi-beat bursts fully supported

### **Write Response Channel** ✓
- Write responses return OKAY (2'b00)
- Correct response timing
- Proper BID (write ID) handling

### **Address Channels** ✓
- Write address channel fully functional
- Read address channel fully functional
- Proper handshaking and ready/valid protocols

---

## Student Debugging Tasks

### **Task 1: Identify the Bug**
- Compare write operations between normal and buggy versions
- Monitor memory writes with FIXED burst type
- Check address calculation for high addresses and sizes

### **Task 2: Pinpoint the Location**
- Locate the incorrect shift operation in write data logic
- Identify the condition checks that trigger the bug

### **Task 3: Understand the Root Cause**
- Analyze why address shift by 1 bit causes data corruption
- Calculate expected vs actual memory addresses
- Trace data flow for failing test cases

### **Task 4: Implement the Fix**
- Correct the address shift calculation
- Verify fix works for all burst types
- Ensure non-triggered cases remain unaffected

---

## Commit History

| Commit SHA | Branch | Message |
|------------|--------|---------|
| `832d024c9...` | buggy-with-error-response | Add FIXED burst write bug - incorrect memory capture for addr>100 and size>5 |
| Previous commits | buggy-with-error-response | Earlier fixes and memory initialization |
| Head | main | Clean, working reference implementation |

---

## Notes for Instructors

1. **Difficulty Level**: Intermediate
   - Requires understanding of AXI-4 burst protocols
   - Needs trace analysis to identify condition triggers
   - Tests bit manipulation and address calculation knowledge

2. **Verification Approach**:
   - Use testbench with parametrized test cases
   - Compare memory results between main and buggy branches
   - Check address mapping for FIXED bursts with high addresses/sizes

3. **Learning Outcomes**:
   - Understanding address conversion in memory interfaces
   - AXI-4 burst type handling
   - RTL debugging and verification techniques
   - Conditional logic verification

---

**Document Version**: 1.0  
**Last Updated**: June 8, 2026  
**Status**: Ready for Student Practice
