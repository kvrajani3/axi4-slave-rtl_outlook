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
This specification defines the features, capabilities, and limitations of a custom AXI-4 slave RTL implementation in Verilog. The design provides a simplified but functional AXI-4 interface for memory/peripheral modelling and verification exercises.

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

... (rest of file same as in main update) ...