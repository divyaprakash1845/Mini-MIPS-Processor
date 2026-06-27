# Mini MIPS Processor & Hardware Accelerators

**Tech Stack:** Verilog HDL, C, Xilinx Vivado, Vitis IDE, AXI4 Memory-Mapped IP, PYNQ-Z2 (ZYNQ-7000 SoC)

A 32-bit Multi-Cycle Soft-Core CPU & Custom AXI4 Accelerators built for the Xilinx PYNQ-Z2 FPGA.

## Project Overview
This repository contains the RTL source code, testbenches, and bare-metal C-firmware for a custom 32-bit System-on-Chip (SoC). It features a custom 3-cycle MIPS processor alongside three hardware accelerators. The architecture strictly enforces structural datapath arithmetic to ensure predictable FPGA synthesis and avoid multi-driver conflicts.

## Architecture Layout

```text
├── src/
│   ├── hdl/                       # Hardware Description (Verilog)
│   │   ├── primitives/            # Custom Math Primitives Library
│   │   │   ├── Adder.v            # Structural Ripple-Carry Logic
│   │   │   ├── multiplier.v       # Iterative Multiplier
│   │   │   ├── divider.v          # Iterative Divider
│   │   │   └── comparator.v       # 1-bit Comparator
│   │   ├── alu.v                  # Combinational Arithmetic Logic Unit
│   │   ├── defs.vh                # Global Opcode & Func Macro Definitions
│   │   ├── Memory.v               # 4KB Data & Instruction Memory
│   │   ├── RegisterFile.v         # 128-Byte MIPS Register File
│   │   ├── Processor.v            # 3-Cycle MIPS CPU FSM Controller
│   │   ├── Computer.v             # Top-Level CPU & Memory Wrapper
│   │   └── accelerators/          # AXI-Lite Hardware Accelerators
│   │       ├── VectorAccelerator.v  
│   │       ├── MatrixAccelerator.v  
│   │       └── GraphAccelerator.v   
│   ├── sw/                        # Firmware (Vitis C Applications)
│   │   └── accelerators/          
│   │       ├── vector_app.c       
│   │       ├── matrix_app.c       
│   │       └── graph_app.c        
│   └── tb/                        # Behavioral Testbenches
│       ├── tb_computer.v          
│       └── accelerators/          
├── IP_PACKAGING_GUIDE.md          # Guide for AXI-Lite Memory-Mapped IP Packaging
└── README.md
```

## 1. 32-bit MIPS Soft-Core
The processor operates on a highly optimized, easy-to-verify **3-Cycle Finite State Machine**:

1. **Cycle 1: Fetch & Read (`S_FETCH_READ`)** - Fetches the 32-bit instruction from memory, decodes it, and reads operand values from the Register File.
2. **Cycle 2: Execute (`S_EXECUTE`)** - The ALU performs arithmetic, logical, or shifting operations based on registered inputs. Syscalls are evaluated here.
3. **Cycle 3: Writeback (`S_WRITEBACK`)** - The final computed result is committed to the Register File, and the Program Counter (PC) is updated.

**Key Technical Features:**
* **Strict Structural Arithmetic:** The Program Counter (PC) and ALU rely on manually instantiated structural `RippleCarryAdder32` and `FullAdder` modules, avoiding unpredicted LUT explosion.
* **$0 Hardwire:** Ensures register $0 remains absolute zero across all reads.
* **Modular Datapath:** Clean separation of the ALU, Register File (128-Byte), Memory Array (4KB), and the core FSM Controller.

### Custom Math Primitives (`src/hdl/primitives/`)
To avoid unpredictable DSP slice allocation by the Vivado synthesizer, complex arithmetic logic was built from the ground up:
* **Ripple-Carry Logic:** Structural multi-bit adders and cascading comparators.
* **Complex Arithmetic:** Custom iterative Divider and Multiplier sequential units.

## 2. FPGA Hardware Accelerators
Three parallel accelerators were synthesized to exploit FPGA fabric density. These are packaged as AXI4 Peripherals and controlled by the ARM Cortex-A9 Processing System via Vitis IDE.

| Accelerator | Hardware Approach | Speedup over ARM |
| :--- | :--- | :--- |
| **Vector Addition** | `generate for` loops for 512 parallel structural adds + 9-cycle tree reduction. | **~150–200x** |
| **Matrix-Vector Mul** | Row inner products via 4-level structural tree reduction (7 cycles per row). | **~16x** |
| **Graph Pathfinding** | Boolean matrix multiplication ($A^k$) using packed 32-bit bitwise-ANDs. | **~1000x** |

## 🚀 Getting Started
1. Create a new Vivado RTL project targeting the PYNQ-Z2 board.
2. Add the source files from `src/hdl/`.
3. Export the bitstream (`.xsa`) to Xilinx Vitis IDE.
4. Compile and run the bare-metal C applications located in `src/sw/accelerators/` on the ARM processor.

---
*Context: Developed for CS220 (Computer Organization) at the Indian Institute of Technology, Kanpur (IITK).*
