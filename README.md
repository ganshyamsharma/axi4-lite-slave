# AXI4-Lite Memory-Mapped Slave Peripheral & Verification Environment

This repository contains a fully compliant, from-scratch **AXI4-Lite Slave Peripheral** implemented in Verilog, alongside a **Verification Environment**. 

This project demonstrates robust cycle-accurate logic, completely decoupled Read/Write state machines, hardware boundary protection, and advanced testbench methodologies using custom **Bus Functional Models (BFMs)**.

---

## 🎯 Verification Strategy & Testbench Features

Unlike simple directed testbenches that manually toggle signals, the verification environment (`tb_axi4_lite_slave.v`) treats the Device Under Test (DUT) with pre-silicon ASIC rigor. It implements customized parallel tasks to stress-test the protocol, handle data hazards, and verify exact timing boundaries.

### 1. Master Bus Functional Models (BFMs)
The testbench abstracts complex AMBA handshaking into highly reusable Verilog tasks (`axi_write` and `axi_read`). These tasks ensure zero wasted clock cycles (minimal latency) and utilize strict synchronous evaluation (`wait` aligned to `posedge aclk`) to prevent race conditions and delta-delay simulation bugs.

### 2. Parallel Channel Concurrency (`fork...join`)
The AXI specification dictates that Write Address (`AW`) and Write Data (`W`) channels are entirely independent. The master is legally permitted to send data before an address, or assert both simultaneously. 
* **Feature:** The testbench utilizes procedural `fork...join` blocks within the BFM tasks to spawn parallel execution threads. This ensures the testbench concurrently processes independent channel handshakes without deadlocking, verifying that the decoupled slave FSMs can handle out-of-order channel arrivals.

### 3. Byte-Lane Access Verification (`WSTRB` Corner Cases)
AXI4-Lite supports partial word updates via the 4-bit Write Strobe (`WSTRB`) mask. 
* **Feature:** The testbench executes unaligned and narrow transfers (e.g., asserting `WSTRB = 4'b0100` to overwrite only bits `[23:16]`). Subsequent read-back verification confirms that the specified byte lane was updated while the remaining adjacent bytes in the 32-bit register were safely preserved without corruption.

### 4. Hardware Security & Boundary Protection (Symmetrical Error Handling)
Relying entirely on system interconnect routers for security is insufficient for high-reliability silicon. The DUT actively defends its internal memory map against aliasing (address wrap-around) and unauthorized access.
* **Out-of-Bounds Write Prevention:** The testbench intentionally initiates writes to invalid addresses outside the allocated register space. It verifies that the slave successfully completes the handshake, drops the payload to prevent memory corruption, and correctly asserts a **`SLVERR` (`2'b10`)** response on the `BRESP` lines.
* **Out-of-Bounds Read Protection (Data Leakage Prevention):** Attempting to read from an unmapped address triggers strict boundary defenses. The testbench confirms that the slave asserts a **`SLVERR`** response while actively forcing the `RDATA` bus to `32'b0`, successfully preventing sensitive memory contents from leaking to rogue software.

### 5. Watchdog Timeout & Protocol Violation Monitoring
To guarantee testbench reliability during regression suites:
* **Feature:** The environment implements background hardware monitors and watchdog counters. If an impatient master drops `VALID` before receiving `READY`, or if a channel hangs for more than 500 clock cycles, the testbench actively catches the failure, asserts `$fatal` to immediately halt execution, and logs the precise timing violation.

---

## 🛠️ Simulation Scenarios Executed

Running the simulation automatically executes the following robust test sequence:

1. **Standard 32-bit Access:** Writes a full 32-bit payload (`0xDEADBEEF`) with all strobes active (`4'b1111`) and reads it back to verify core pipeline integrity.
2. **Byte-Lane Strobing:** Overwrites a single byte lane of an existing register using partial strobes, confirming precise bit-slicing logic.
3. **Write Aliasing Defense:** Drives an out-of-bounds address (`0x0000_0400`) to confirm data dropping and `SLVERR` generation.
4. **Read Leakage Defense:** Reads from an out-of-bounds address to confirm the zeroing-out of the data bus alongside `SLVERR` generation.

---

## 📊 Waveform Analysis

When viewing the simulation in **GTKWave**, **Vivado**, or **ModelSim**, observe the following signals to confirm 1-cycle minimal latency handshakes:

* `i_aclk` / `i_aresetn`
* **Write Channels:** `i_awvalid`, `o_awready`, `i_wvalid`, `o_wready`, `o_bvalid`, `i_bready`, `o_bresp`
* **Read Channels:** `i_arvalid`, `o_arready`, `o_rvalid`, `i_rready`, `o_rdata`, `o_rresp`

*Notice that the look-ahead registered outputs inside the slave allow `READY` and `VALID` signals to assert and de-assert in exactly one clock cycle, matching maximum interconnect throughput standards.*
