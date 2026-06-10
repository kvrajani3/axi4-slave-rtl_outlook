# AXI-4 Slave RTL Specification Document

**Document Version**: 1.0  
**Date**: May 28, 2026  
**Status**: Final  
**Author**: RTL Design Team

---

## Table of Contents

1. [Overview](#overview)
2. [Protocol Compliance](#protocol-compliance)
3. [Data Channel Specifications](#data-channel-specifications)
4. [Burst Mode Specifications](#burst-mode-specifications)
5. [Transaction Handling](#transaction-handling)
6. [Memory Specifications](#memory-specifications)
7. [Handshake Protocol](#handshake-protocol)
8. [Features & Limitations](#features--limitations)
9. [Performance Characteristics](#performance-characteristics)
10. [Configuration Parameters](#configuration-parameters)
11. [Design Constraints](#design-constraints)
12. [Use Cases](#use-cases)
13. [Revision History](#revision-history)

---

## 1. Overview

### Purpose
This specification defines the features, capabilities, and limitations of a custom AXI-4 slave RTL implementation in Verilog. The design provides a simplified but functional AXI-4 interface for memory controllers and peripherals.

### Scope
- **Target Application**: Memory controllers, peripheral interfaces, test benches
- **Design Level**: RTL (Register Transfer Level)
- **Implementation**: Synthesizable Verilog
- **Focus**: Feature specification, not implementation details

### Key Characteristics
- Full handshaking on all AXI channels
- Support for all three burst modes (FIXED, INCR, WRAP)
- Configurable data width, address width, and ID width
- Integrated local memory (4 KB default)
- Byte-level write control via strobes

---

## 2. Protocol Compliance

### AXI-4 Standard Support

| Aspect | Status | Notes |
|--------|--------|-------|
| **AXI Protocol Version** | AXI4 (AMBA 4) | Full AXI4 protocol variant |
| **Compliance Level** | AXI4 Lite+ | Simplified full AXI4 (no ACE) |
| **Standard Coverage** | ~75% | Core functionality, limited advanced features |

### Supported Protocol Variants
- ✓ **AXI4**: Full protocol support (except ACE extensions)
- ✗ **AXI4-ACE**: No coherency protocol support
- ✗ **AXI4-Lite**: More restricted than this implementation (ACE Lite subset)

### Protocol Features NOT Supported
- Exclusive access (atomic transactions)
- QoS (Quality of Service) routing
- Cache policies and coherency
- Access protection levels
- Region-based addressing
- Error responses (SLVERR, DECERR, EXOKAY)

---

## 3. Data Channel Specifications

### 3.1 Write Address Channel (AW)

| Signal | Width | Direction | Status | Description |
|--------|-------|-----------|--------|-------------|
| **AWID** | ID_WIDTH (def: 12) | Input | ✓ Supported | Write transaction identifier |
| **AWADDR** | ADDR_WIDTH (def: 32) | Input | ✓ Supported | Write address |
| **AWLEN** | 8 bits | Input | ✓ Supported | Burst length (0-255 beats) |
| **AWSIZE** | 3 bits | Input | ✓ Supported | Bytes per beat (2^AWSIZE) |
| **AWBURST** | 2 bits | Input | ✓ Supported | Burst type (FIXED, INCR, WRAP) |
| **AWVALID** | 1 bit | Input | ✓ Supported | Address valid signal |
| **AWREADY** | 1 bit | Output | ✓ Supported | Slave ready to accept address |
| AWLOCK | - | - | ✗ Not Supported | Exclusive access not supported |
| AWCACHE | - | - | ✗ Not Supported | Cache policy not supported |
| AWPROT | - | - | ✗ Not Supported | Protection type not supported |
| AWREGION | - | - | ✗ Not Supported | Region identifier not supported |
| AWQOS | - | - | ✗ Not Supported | QoS not supported |

**Notes**:
- AWSIZE must be within range [0:3] for 32-bit data (1, 2, 4, 8 bytes)
- Address is byte-addressable but access is word-aligned
- Up to 256 beats per transaction (AWLEN = 0 to 255)

---

### 3.2 Write Data Channel (W)

| Signal | Width | Direction | Status | Description |
|--------|-------|-----------|--------|-------------|
| **WDATA** | DATA_WIDTH (def: 32) | Input | ✓ Supported | Write data payload |
| **WSTRB** | DATA_WIDTH/8 (def: 4) | Input | ✓ Supported | Write strobes (byte enables) |
| **WLAST** | 1 bit | Input | ✓ Supported | Last transfer in burst |
| **WVALID** | 1 bit | Input | ✓ Supported | Data valid signal |
| **WREADY** | 1 bit | Output | ✓ Supported | Slave ready for data |
| WID | - | - | ✗ Removed in AXI4 | Write ID channel removed |

**WSTRB Bit Mapping**:
```
WSTRB[0] → Byte 0 (bits 7:0)
WSTRB[1] → Byte 1 (bits 15:8)
WSTRB[2] → Byte 2 (bits 23:16)
WSTRB[3] → Byte 3 (bits 31:24)
```

**Notes**:
- All WSTRB bits = 1 indicates full word write
- Partial WSTRB enables byte-level selective writes
- WDATA must be presented for each WVALID beat

---

### 3.3 Write Response Channel (B)

| Signal | Width | Direction | Status | Description |
|--------|-------|-----------|--------|-------------|
| **BID** | ID_WIDTH (def: 12) | Output | ✓ Supported | Response identifier (matches AWID) |
| **BRESP** | 2 bits | Output | ✓ Supported | Response status |
| **BVALID** | 1 bit | Output | ✓ Supported | Response valid signal |
| **BREADY** | 1 bit | Input | ✓ Supported | Master ready for response |

**BRESP Values**:

| Code | Meaning | Implementation |
|------|---------|------------------|
| 2'b00 | OKAY | ✓ Always returned |
| 2'b01 | EXOKAY | ✗ Not supported |
| 2'b10 | SLVERR | ✗ Not supported |
| 2'b11 | DECERR | ✗ Not supported |

**Notes**:
- Response issued after WLAST received
- BID always matches AWID of corresponding write transaction
- Single response per write burst

---

### 3.4 Read Address Channel (AR)

| Signal | Width | Direction | Status | Description |
|--------|-------|-----------|--------|-------------|
| **ARID** | ID_WIDTH (def: 12) | Input | ✓ Supported | Read transaction identifier |
| **ARADDR** | ADDR_WIDTH (def: 32) | Input | ✓ Supported | Read address |
| **ARLEN** | 8 bits | Input | ✓ Supported | Burst length (0-255 beats) |
| **ARSIZE** | 3 bits | Input | ✓ Supported | Bytes per beat (2^ARSIZE) |
| **ARBURST** | 2 bits | Input | ✓ Supported | Burst type (FIXED, INCR, WRAP) |
| **ARVALID** | 1 bit | Input | ✓ Supported | Address valid signal |
| **ARREADY** | 1 bit | Output | ✓ Supported | Slave ready to accept address |
| ARLOCK | - | - | ✗ Not Supported | Exclusive access not supported |
| ARCACHE | - | - | ✗ Not Supported | Cache policy not supported |
| ARPROT | - | - | ✗ Not Supported | Protection type not supported |
| ARREGION | - | - | ✗ Not Supported | Region identifier not supported |
| ARQOS | - | - | ✗ Not Supported | QoS not supported |

**Notes**:
- Identical signal structure to Write Address Channel
- Same size and burst length constraints as write channel

---

### 3.5 Read Data Channel (R)

| Signal | Width | Direction | Status | Description |
|--------|-------|-----------|--------|-------------|
| **RID** | ID_WIDTH (def: 12) | Output | ✓ Supported | Data identifier (matches ARID) |
| **RDATA** | DATA_WIDTH (def: 32) | Output | ✓ Supported | Read data payload |
| **RRESP** | 2 bits | Output | ✓ Supported | Response status |
| **RLAST** | 1 bit | Output | ✓ Supported | Last transfer in burst |
| **RVALID** | 1 bit | Output | ✓ Supported | Data valid signal |
| **RREADY** | 1 bit | Input | ✓ Supported | Master ready for data |

**RRESP Values**: Same as BRESP (only OKAY implemented)

**Notes**:
- RDATA updated for each beat
- RLAST asserted on final beat of burst
- RID maintained throughout transaction

---

## 4. Burst Mode Specifications

### 4.1 Supported Burst Types

#### FIXED Burst (2'b00)
- **Description**: Address remains constant for all beats
- **Address Behavior**: No increment between beats
- **Use Case**: Single location repeated write/read (e.g., FIFO)
- **Implementation**: ✓ Fully Supported

```
Transaction: AWLEN=3, AWSIZE=2 (4 bytes), AWBURST=FIXED
Beat 0: Address = 0x1000
Beat 1: Address = 0x1000  (same)
Beat 2: Address = 0x1000  (same)
Beat 3: Address = 0x1000  (same)
```

#### INCR Burst (2'b01)
- **Description**: Address increments for each beat
- **Address Increment**: 2^AWSIZE or 2^ARSIZE bytes per beat
- **Use Case**: Typical memory access, streaming data
- **Implementation**: ✓ Fully Supported

```
Transaction: AWLEN=3, AWSIZE=2 (4 bytes), AWBURST=INCR
Beat 0: Address = 0x1000
Beat 1: Address = 0x1004  (0x1000 + 4)
Beat 2: Address = 0x1008  (0x1004 + 4)
Beat 3: Address = 0x100C  (0x1008 + 4)
```

#### WRAP Burst (2'b10)
- **Description**: Address wraps within a burst-size boundary
- **Wrap Boundary**: (AWLEN+1) × 2^AWSIZE bytes
- **Use Case**: Cache line fills, descriptor rings
- **Implementation**: ✓ Fully Supported
- **Calculation**:
  ```
  Burst_Mask = ((AWLEN + 1) << AWSIZE) - 1
  Next_Addr = (Current_Addr & ~Burst_Mask) | 
              ((Current_Addr + 2^AWSIZE) & Burst_Mask)
  ```

```
Transaction: AWLEN=3, AWSIZE=2 (4 bytes), AWBURST=WRAP
Wrap_Boundary = (3+1) × 4 = 16 bytes = 0x10
Burst_Mask = 0x0F

Beat 0: Address = 0x1000 (aligned to boundary)
Beat 1: Address = 0x1004 (wraps within 0x1000-0x100F)
Beat 2: Address = 0x1008
Beat 3: Address = 0x100C
Beat 4 (if existed): Address = 0x1000 (wraps back)

Starting at unaligned address:
Beat 0: Address = 0x1008
Beat 1: Address = 0x100C
Beat 2: Address = 0x1000 (wraps)
Beat 3: Address = 0x1004 (wraps)
```

### 4.2 Burst Length

| Aspect | Specification |
|--------|---------------|
| **Range** | 1 to 256 beats |
| **Signal Values** | AWLEN/ARLEN = 0 to 255 |
| **Actual Length** | AWLEN/ARLEN + 1 |
| **Encoding** | AWLEN=0 → 1 beat, AWLEN=255 → 256 beats |
| **Maximum Data** | 256 × DATA_WIDTH bits per transaction |

### 4.3 Transfer Size

| Size Code | Bytes per Beat | Bit Width | Usage |
|-----------|----------------|-----------|-------|
| 3'b000 | 1 | 8-bit | Byte transfers |
| 3'b001 | 2 | 16-bit | Half-word transfers |
| 3'b010 | 4 | 32-bit | Word transfers |
| 3'b011 | 8 | 64-bit | Double-word transfers |
| 3'b100 | 16 | 128-bit | Quad-word transfers |
| 3'b101 | 32 | 256-bit | - |
| 3'b110 | 64 | 512-bit | - |
| 3'b111 | 128 | 1024-bit | - |

**Notes**:
- AWSIZE/ARSIZE value of N means 2^N bytes per beat
- Maximum size depends on DATA_WIDTH configuration
- All transactions must respect memory word alignment

---

## 5. Transaction Handling

### 5.1 Write Transaction Flow

#### Phase 1: Address Phase
```
1. Master asserts AWVALID with address, length, size, burst info
2. Slave checks AWREADY
3. When both AWVALID and AWREADY are high (handshake):
   - Slave captures AWID, AWADDR, AWLEN, AWSIZE, AWBURST
   - Slave de-asserts AWREADY (ready for next address)
   - Slave enters data phase
4. Master releases AWVALID
```

**Timing**: Address accepted in single cycle if AWREADY=1

#### Phase 2: Data Phase

```
1. Slave asserts WREADY to indicate readiness for data
2. Master provides WDATA and WSTRB on each cycle
3. On WVALID and WREADY handshake:
   - Data written to memory (byte-enabled by WSTRB)
   - Address incremented per burst type
   - Beat counter incremented
4. Master asserts WLAST on final beat
5. Data phase continues until WLAST and WREADY both true
```

**Timing**: Data transfers at 1 beat per cycle (if WREADY always high)

#### Phase 3: Response Phase

```
1. Slave captures WLAST and final beat of data
2. Next cycle: Slave asserts BVALID with BID and BRESP
3. Response held until BREADY asserted (handshake)
4. BRESP = 2'b00 (OKAY) always
5. Slave de-asserts BVALID, ready for next address
```

**Timing**: Response issued 1 cycle after WLAST

### 5.2 Read Transaction Flow

#### Phase 1: Address Phase

```
1. Master asserts ARVALID with address, length, size, burst
2. Slave checks ARREADY
3. Handshake occurs when both ARVALID and ARREADY high:
   - Slave captures ARID, ARADDR, ARLEN, ARSIZE, ARBURST
   - Slave de-asserts ARREADY
   - Slave begins data fetch from memory
4. Master releases ARVALID
```

#### Phase 2: Data Phase

```
1. Slave asserts RVALID to present data
2. On first handshake (RVALID & RREADY):
   - RDATA contains read data from memory
   - RLAST = 0 if more beats remain
3. On subsequent handshakes:
   - Address incremented per burst type
   - New RDATA fetched from updated address
   - RLAST remains 0 until final beat
4. On final beat:
   - RLAST = 1
   - RVALID remains high until RREADY
   - Transaction complete after final handshake
```

**Timing**: Data available 1 cycle after address acceptance

---

## 6. Memory Specifications

### 6.1 Internal Memory Architecture

| Aspect | Specification |
|--------|---------------|
| **Size** | Configurable (default 4 KB = 1024 words) |
| **Word Width** | Configurable (default 32-bit) |
| **Address Space** | Complete address range (up to 32-bit) |
| **Access Type** | Word-aligned synchronous RAM |
| **Memory Type** | Behavioral Verilog array |

### 6.2 Address Mapping

```
Physical Address (byte address):  [ADDR_WIDTH-1:0]
                                   ↓
Memory Word Index:  address[ADDR_WIDTH-1:2]
                    (divides by 4 for 32-bit word)

Example (32-bit words):
Byte Address    Word Index    Data
0x1000          0x400         word[0x400]
0x1004          0x401         word[0x401]
0x1008          0x402         word[0x402]
```

---

## 7. Handshake Protocol

### 7.1 Valid-Ready Handshake Mechanism

The AXI protocol uses a valid-ready handshake mechanism on all channels to control the flow of transactions. This ensures both master and slave are in sync.

**Handshake Rules**:
- **VALID**: Driven by sender (Master for address/data, Slave for response/data)
- **READY**: Driven by receiver (Slave for address/data, Master for response/data)
- **Transfer occurs** when both VALID and READY are high on the rising clock edge
- Signals remain stable until transfer occurs

### 7.2 Write Address Channel Handshake

**AWVALID / AWREADY**:

| Scenario | AWVALID | AWREADY | Action |
|----------|---------|---------|--------|
| Idle | Low | Any | No transfer |
| Ready to accept | High | High | Address captured, transfer complete |
| Slave busy | High | Low | Wait for AWREADY |
| Master not ready | Low | High | No transfer |

**Flow**:
1. Master asserts AWVALID with valid address/control signals
2. Slave asserts AWREADY when ready to accept
3. On rising edge with both high: address latched, transaction begins
4. AWVALID is released by master; AWREADY may remain high or be released

### 7.3 Write Data Channel Handshake

**WVALID / WREADY**:

| Scenario | WVALID | WREADY | WLAST | Action |
|----------|--------|--------|-------|--------|
| Idle | Low | Any | - | No transfer |
| Data ready, slave ready | High | High | 0 | Data beat accepted |
| Data ready, slave ready (last) | High | High | 1 | Final data beat, response pending |
| Data ready, slave busy | High | Low | - | Data beat stalled |

**Flow**:
1. Slave asserts WREADY to indicate readiness for data beats
2. Master asserts WVALID with data and strobes
3. On rising edge with both high: data written to internal storage
4. Process repeats until WLAST and handshake occur
5. After WLAST handshake, data phase ends and response phase begins

### 7.4 Write Response Channel Handshake

**BVALID / BREADY**:

| Scenario | BVALID | BREADY | Action |
|----------|--------|--------|--------|
| Idle | Low | Any | No response |
| Response ready, master ready | High | High | Response captured, transfer complete |
| Response ready, master busy | High | Low | Response held, wait for BREADY |
| Slave preparing response | Low | Any | No response available |

**Flow**:
1. After all write data accepted (WLAST + WREADY), slave prepares response
2. Slave asserts BVALID with response ID and status
3. On rising edge with BVALID and BREADY both high: response captured
4. Slave releases BVALID after handshake, ready for next write address

### 7.5 Read Address Channel Handshake

**ARVALID / ARREADY**:

Identical protocol to Write Address Channel (AWVALID/AWREADY):
- Master asserts ARVALID with read address
- Slave asserts ARREADY when ready to accept
- Handshake on rising edge with both high
- Read address captured and data fetch begins

### 7.6 Read Data Channel Handshake

**RVALID / RREADY**:

| Scenario | RVALID | RREADY | RLAST | Action |
|----------|--------|--------|-------|--------|
| Idle | Low | Any | - | No data |
| Data ready, master ready | High | High | 0 | Data beat transferred |
| Data ready, master ready (last) | High | High | 1 | Final data beat, read complete |
| Data ready, master busy | High | Low | - | Data held, master stalled |

**Flow**:
1. After read address accepted, slave fetches first data beat
2. Slave asserts RVALID with data, RLAST=0 for non-final beats
3. On handshake, address incremented per burst type, next beat fetched
4. On final beat, RLAST asserted
5. After final handshake with RLAST high, read transaction complete

### 7.7 Handshake Timing Diagram

**Example Write Transaction (4-beat burst)**:

```
Clock:      |_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|
AWVALID:    __|‾‾‾|_______|___________________|_______
AWREADY:    _________|‾‾‾|_____________________________
WVALID:     _|‾‾‾‾‾‾‾‾‾‾‾|_____________________________
WREADY:     _______|‾‾‾‾‾|_____________________________
WLAST:      _|_______|_______|_______|‾|___________
BVALID:     _|________________________|‾‾‾|_________
BREADY:     _|___________________________|‾‾|_______

Cycle:      0  1  2  3  4  5  6  7  8  9  10 11 12 13

- Cycle 1: AWVALID & AWREADY → Address captured
- Cycle 2-5: WVALID & WREADY → Data beats 0-3 transferred
- Cycle 6: After WLAST, response prepared
- Cycle 7: BVALID & BREADY → Response captured
```

### 7.8 Important Handshake Rules

1. **Sender Stability**: All signals from sender (VALID side) must remain stable until handshake
2. **Receiver Control**: Receiver (READY side) can assert/de-assert READY independently
3. **No Combinational Logic**: Sender must not use READY to combinationally generate VALID
4. **Hold until Handshake**: Master must not release VALID until READY asserted (unless specified otherwise)
5. **Sequential Release**: Slave must not assume master behavior; any handshake protocol is valid

---

## 8. Features & Limitations

### 8.1 Supported Features ✓

| Feature | Status | Notes |
|---------|--------|-------|
| Configurable data width | ✓ | 8 to 128+ bits |
| Configurable address width | ✓ | Up to 32 bits |
| Configurable ID width | ✓ | 1 to 16 bits typical |
| FIXED burst mode | ✓ | Address constant |
| INCR burst mode | ✓ | Address increment |
| WRAP burst mode | ✓ | Address wrap around |
| Burst length 1-256 | ✓ | Full range support |
| Byte-enable strobes | ✓ | Per-byte write control |
| Transaction IDs | ✓ | Maintained through transaction |
| Separate read/write channels | ✓ | Independent path control |
| Full handshaking | ✓ | Valid-ready on all channels |
| Protocol timing compliance | ✓ | Per AXI4 specification |

### 8.2 Not Supported Features ✗

| Feature | Status | Reason |
|---------|--------|--------|
| Exclusive access (LOCK) | ✗ | Atomic operations not implemented |
| Cache policies (CACHE) | ✗ | No cache coherency |
| Protection types (PROT) | ✗ | No security model |
| QoS routing (QoS) | ✗ | No priority handling |
| Region signals (REGION) | ✗ | No address region support |
| Error responses | ✗ | Only OKAY response generated |
| Write data interleaving | ✗ | Sequential write enforced |
| Out-of-order completion | ✗ | In-order only |
| Multiple outstanding addresses | ✗ | Single pending per channel |
| Narrow transfers | ✗ | Must use byte strobes |
| CDC (Clock Domain Crossing) | ✗ | Single clock domain only |

---

## 9. Performance Characteristics

### 9.1 Write Performance

| Scenario | Cycles | Notes |
|----------|--------|-------|
| Address acceptance | 1 | Synchronous capture |
| Data beat | 1 | Per beat (if WREADY continuous) |
| 4-beat burst | 4 | 4 data cycles minimum |
| Full transaction (4 beats) | 6 | 1 addr + 4 data + 1 resp |
| Response after WLAST | 1 | 1 cycle delay |

### 9.2 Read Performance

| Scenario | Cycles | Notes |
|----------|--------|-------|
| Address to first data | 2 | 1 capture + 1 fetch |
| Data beat | 1 | Per beat (if RREADY continuous) |
| 4-beat burst | 4 | 4 data cycles |
| Address to last data | 5 | 1 addr + 4 data |
| Throughput after first | 1/cycle | Pipelined |

---

## 10. Configuration Parameters

### 10.1 Parameterizable Generics

```verilog
module axi4_slave #(
    parameter DATA_WIDTH = 32,      // Bits: 8, 16, 32, 64, 128, etc.
    parameter ADDR_WIDTH = 32,      // Bits: 12-32 typical
    parameter ID_WIDTH = 12,        // Bits: 1-16 (typically 4-12)
    parameter MEM_SIZE = 4096       // Words: size in elements
)
```

### 10.2 Parameter Definitions

#### DATA_WIDTH
- **Range**: 8 to 256 bits (in multiples of 8)
- **Default**: 32 bits
- **Impact**: Affects WDATA, RDATA bus width and WSTRB width

#### ADDR_WIDTH
- **Range**: 10 to 32 bits
- **Default**: 32 bits
- **Impact**: Affects AWADDR, ARADDR width

#### ID_WIDTH
- **Range**: 1 to 16 bits
- **Default**: 12 bits
- **Impact**: Affects AWID, ARID, BID, RID width

#### MEM_SIZE
- **Range**: 1 to 2^(ADDR_WIDTH-2) words
- **Default**: 1024 (4 KB for 32-bit words)
- **Impact**: Internal memory array size

---

## 11. Design Constraints

### 11.1 Functional Constraints

- **Single Outstanding Address**: Only ONE write/read address can be pending at a time
- **Sequential Data Delivery**: Data beats must be delivered in order
- **In-Order Completion**: Transactions complete in order

### 11.2 Timing Constraints

- **Synchronous Design**: All logic synchronized to rising clock edge
- **Reset Active Low**: Asynchronous reset_n (must assert for 2 cycles)

### 11.3 Ready Signal Duration Guidance

The AXI specification places no explicit upper bound on how many cycles a slave may de-assert a READY signal (AWREADY, WREADY, ARREADY, RREADY); a slave may legally de-assert READY for an arbitrary duration while remaining AXI-compliant.

However, practical system integration requires explicit bounds on READY stall duration. **For this implementation, the slave READY signals (AWREADY, WREADY, ARREADY, RREADY) shall not be de-asserted for more than 1024 clock cycles consecutively without reassertion.** This maximum stall duration of **1024 cycles** serves as the design contract between the AXI slave and its master/system integration point.

**Key Guidelines**:

- **Maximum Stall**: All slave READY signals shall not exceed **1024 consecutive cycles** of de-assertion
- **Per-Signal Limits**: Recommend tracking stall duration individually for each signal:
  - AWREADY max stall: 1024 cycles
  - WREADY max stall: 1024 cycles  
  - ARREADY max stall: 1024 cycles
  - RREADY: Not applicable (master-driven signal)

**Verification & Monitoring**:

Use DV/CI monitors and assertions that flag READY low durations exceeding the agreed limit so potential livelock or performance regressions are detected early.

Example testbench/watchdog pseudocode:
```
if (awvalid && !awready) count_aw_stall++;
else count_aw_stall = 0;
assert (count_aw_stall < 1024) else $error("AWREADY stalled for > 1024 cycles");

if (wvalid && !wready) count_w_stall++;
else count_w_stall = 0;
assert (count_w_stall < 1024) else $error("WREADY stalled for > 1024 cycles");

if (arvalid && !arready) count_ar_stall++;
else count_ar_stall = 0;
assert (count_ar_stall < 1024) else $error("ARREADY stalled for > 1024 cycles");
```

**System Integration Notes**:

- If a bounded READY stall is required for a given deployment (real-time, QoS-sensitive), implement and verify that bound in both RTL (if necessary) and the testbench/watcher infrastructure.
- The system integrator may define stricter limits than 1024 cycles based on specific application requirements; however, 1024 cycles is the maximum acceptable default for this implementation.
- Record these signal-specific stall limits in the module-level integration documentation.

### 11.4 Address Space Constraints

- **Linear Addressing**: No address translation or remapping
- **Word Alignment**: Minimum access is word boundary
- **No Protected Regions**: All memory equally accessible

---

## 12. Use Cases

### 12.1 Recommended Applications

✓ **Simple Memory Controllers**
- System RAM interface
- Register banks
- Configuration memory

✓ **Peripheral Interfaces**
- UART controllers
- SPI masters/slaves
- GPIO modules
- Timer/counter blocks

✓ **Test & Verification**
- Testbench memories
- Behavioral models
- System-level simulation

✓ **FPGA Prototyping**
- Quick integration
- Proof-of-concept designs
- Educational designs

### 12.2 Not Recommended For

✗ **High-Performance Systems** - Requires multiple outstanding transactions
✗ **Safety-Critical Applications** - No error detection/correction
✗ **Multi-Clock Domain Systems** - No CDC support
✗ **Advanced Coherency** - No ACE/AXI-ACE support

---

## 13. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|----------|
| 1.0 | 2026-05-28 | RTL Design Team | Initial specification document |
| 1.1 | 2026-06-10 | RTL Design Team | Added explicit Ready Signal Duration Guidance with 1024-cycle maximum stall limit |
| 1.2 | 2026-06-10 | RTL Design Team | Added Section 7: Handshake Protocol with detailed valid-ready mechanism and timing diagrams |

---

## 14. Appendix A: Quick Reference

### Burst Type Quick Reference

| Mode | Code | Address | Example |
|------|------|---------|----------|
| FIXED | 00 | Same | 0x1000, 0x1000, 0x1000, ... |
| INCR | 01 | +4 | 0x1000, 0x1004, 0x1008, ... |
| WRAP | 10 | +4 w/ wrap | 0x1000, 0x1004, 0x1008, 0x100C, 0x1000, ... |

### Default Configuration

```verilog
DATA_WIDTH = 32 bits     // 4-byte words
ADDR_WIDTH = 32 bits     // 4 GB space
ID_WIDTH = 12 bits       // 4096 IDs
MEM_SIZE = 1024 words    // 4 KB memory
```

---

**Document Classification**: Technical Specification  
**Distribution**: Internal / Reference  
**Last Updated**: 2026-06-10
