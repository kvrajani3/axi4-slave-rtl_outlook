# AXI-4 Slave RTL Implementation

A fully synthesizable AXI-4 slave interface in Verilog with support for all three burst modes (FIXED, INCR, WRAP).

## Overview

This repository contains a complete AXI-4 slave implementation designed for:
- Memory controllers
- Peripheral interfaces
- System integration
- RTL verification and testing

## Features

✓ **Full AXI-4 Protocol Support**
- Complete handshaking on all channels (AW, W, B, AR, R)
- Support for all three burst modes: FIXED, INCR, WRAP
- Configurable transaction IDs (up to 4096)
- Burst lengths up to 256 beats

✓ **Configurable Design**
- Data width: 8 to 256+ bits
- Address width: up to 32 bits
- ID width: 1 to 16 bits
- Memory size: fully parameterizable

✓ **Production-Ready Features**
- Byte-level write strobes for selective writes
- Proper address calculation for all burst types
- Synchronous design suitable for FPGA/ASIC
- Clean, well-documented RTL code

## Repository Structure

```
axi4-slave-rtl/
├── README.md                           # This file
├── axi4_slave.v                        # Main RTL implementation
└── AXI4_Slave_RTL_Specification.md     # Complete specification document
```

## Quick Start

### Basic Instantiation

```verilog
axi4_slave #(
    .DATA_WIDTH(32),      // 32-bit data bus
    .ADDR_WIDTH(32),      // 32-bit address space
    .ID_WIDTH(12),        // Support up to 4096 transaction IDs
    .MEM_SIZE(1024)       // 4 KB internal memory
) slave_inst (
    .clk(clk),
    .rst_n(rst_n),
    
    // Write Address Channel
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awvalid(awvalid),
    .awready(awready),
    
    // Write Data Channel
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    
    // Write Response Channel
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),
    
    // Read Address Channel
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arvalid(arvalid),
    .arready(arready),
    
    // Read Data Channel
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready)
);
```

## Burst Mode Examples

### FIXED Burst (2'b00)
Address remains constant - useful for FIFOs
```
AWLEN=3, AWSIZE=2 (4 bytes), AWBURST=FIXED
Beat 0: 0x1000
Beat 1: 0x1000  (same)
Beat 2: 0x1000  (same)
Beat 3: 0x1000  (same)
```

### INCR Burst (2'b01)
Address increments - typical memory access
```
AWLEN=3, AWSIZE=2 (4 bytes), AWBURST=INCR
Beat 0: 0x1000
Beat 1: 0x1004
Beat 2: 0x1008
Beat 3: 0x100C
```

### WRAP Burst (2'b10)
Address wraps within boundary - cache line fills
```
AWLEN=3, AWSIZE=2, AWBURST=WRAP
Wrap Boundary: 16 bytes
Beat 0: 0x1000
Beat 1: 0x1004
Beat 2: 0x1008
Beat 3: 0x100C
Beat 4: 0x1000 (wraps)
```

## Configuration Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| DATA_WIDTH | 32 | 8-256 | Data bus width in bits |
| ADDR_WIDTH | 32 | 10-32 | Address bus width in bits |
| ID_WIDTH | 12 | 1-16 | Transaction ID width in bits |
| MEM_SIZE | 1024 | 1-2^30 | Memory size in words |

### Example Configurations

**Small Peripheral**
```verilog
.DATA_WIDTH(32),
.ADDR_WIDTH(12),    // 4 KB
.ID_WIDTH(4),       // 16 IDs
.MEM_SIZE(1024)
```

**Large Memory**
```verilog
.DATA_WIDTH(64),
.ADDR_WIDTH(32),    // 4 GB
.ID_WIDTH(12),      // 4096 IDs
.MEM_SIZE(262144)   // 2 MB
```

## Protocol Compliance

- **AXI-4 Standard**: Full compliance for implemented features
- **Supported**: All three burst modes, configurable widths, valid-ready handshakes
- **Not Supported**: Exclusive access, QoS, cache policies, error responses
- **Compliance Level**: ~75% of full AXI-4 specification

For complete specification details, see [AXI4_Slave_RTL_Specification.md](AXI4_Slave_RTL_Specification.md)

## Performance Characteristics

### Write Performance
- Address acceptance: 1 cycle
- Data beats: 1 cycle per beat
- Full transaction (4 beats): 6 cycles total
- Response after WLAST: 1 cycle delay

### Read Performance
- Address to first data: 2 cycles
- Subsequent beats: 1 cycle per beat
- Peak throughput: 1 word/cycle after initial latency

## Key Features

### Burst Mode Support
- ✓ FIXED: Constant address (FIFO operations)
- ✓ INCR: Incrementing address (standard memory)
- ✓ WRAP: Wrapping address (cache fills)

### Address Calculation
- Combinational calculation for all burst types
- Automatic boundary detection for WRAP bursts
- No additional latency

### Write Control
- Byte-level write strobes (WSTRB)
- Selective byte enables
- Full word or partial word writes

### Transaction Management
- Transaction ID preservation (AWID→BID, ARID→RID)
- Proper handshaking on all channels
- Single outstanding address per channel
- Sequential data delivery

## Use Cases

✓ Simple memory controllers  
✓ Peripheral interfaces (UART, SPI, GPIO)  
✓ System testbenches  
✓ FPGA prototyping  
✓ Educational designs  

## Not Recommended For

✗ High-performance systems requiring out-of-order completion  
✗ Safety-critical applications  
✗ Multi-clock domain systems  
✗ Applications requiring advanced coherency (ACE)  

## Limitations

- Single outstanding address per channel
- In-order transaction completion only
- No error response generation (always OKAY)
- No exclusive access support
- Single clock domain only

## Document

The complete specification document includes:
- Detailed protocol specification
- Signal definitions and descriptions
- Burst mode examples with diagrams
- Transaction flow descriptions
- Timing characteristics
- Configuration guidelines
- Design constraints
- Use case recommendations

See [AXI4_Slave_RTL_Specification.md](AXI4_Slave_RTL_Specification.md) for complete details.

## Implementation Details

### Memory
- Internal synchronous RAM (behavioral model)
- Configurable size and width
- Word-aligned access
- No parity or ECC

### Reset
- Asynchronous active-low reset (rst_n)
- Clears all registers and memory on assertion
- Requires 2 cycles of assertion for clean reset

### Handshaking
- Standard valid-ready protocol
- Separate read and write channels
- Independent address/data/response channel control

## License

Feel free to use this implementation in your projects.

## Contributing

Contributions are welcome! Please ensure:
- Code follows existing style
- All functionality is documented
- Changes are compatible with AXI-4 specification

## Questions?

Refer to [AXI4_Slave_RTL_Specification.md](AXI4_Slave_RTL_Specification.md) for detailed information about any aspect of the implementation.
