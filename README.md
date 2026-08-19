# DVB-T2 T2-MI to Transport Stream Converter

## Overview

This project implements a DVB-T2 Modulator Interface (T2-MI) decoder in VHDL. It extracts T2-MI packets carried inside an MPEG-2 Transport Stream (TS), decodes DVB-T2 Baseband Frames (BBFRAMEs), and reconstructs the original Transport Stream contained within the DVB-T2 transmission.

The design is intended for FPGA implementation and operates on a byte-oriented transport stream interface. It consists of three main modules:

* **t2mi_to_ts_top** – Top-level integration module
* **ts_parser** – MPEG-TS parser and T2-MI packet extractor
* **t2mi_parser** – DVB-T2 T2-MI decoder and TS rebuilder

The resulting output is a continuous MPEG-TS stream reconstructed from the DVB-T2 Baseband Frames.

---

## Architecture

The system is organized as a two-stage processing pipeline:

```text
             MPEG-TS Input
                    │
                    ▼
        ┌─────────────────────┐
        │      TS Parser      │
        │                     │
        │ • TS Synchronization│
        │ • PID Filtering     │
        │ • CC Verification   │
        │ • PUSI Handling     │
        │ • Pointer Processing│
        └──────────┬──────────┘
                   │
                   ▼
        ┌─────────────────────┐
        │    T2-MI Parser     │
        │                     │
        │ • Header Validation │
        │ • CRC-8 Check       │
        │ • BBFRAME Parsing   │
        │ • SYNCD Removal     │
        │ • UP Extraction     │
        │ • TS Reconstruction │
        └──────────┬──────────┘
                   │
                   ▼
           Rebuilt MPEG-TS
```
Note: The MPEG-TS input is connected to both the TS Parser and the T2-MI Parser in the pipeline.

---

## Features

### Transport Stream Parsing

* MPEG-TS synchronization using sync byte `0x47`
* PID extraction and filtering
* Continuity counter validation
* Adaptation field handling
* Payload Unit Start Indicator (PUSI) processing
* Pointer field processing
* Error detection and recovery

### DVB-T2 T2-MI Decoding

* T2-MI Baseband Frame packet processing
* Header field verification
* PLP ID validation
* MATYPE verification
* DVB-T2 CRC-8 verification
* Payload length extraction
* DFL and SYNCD processing
* Baseband padding removal
* CRC32 field skipping

### Transport Stream Reconstruction

* User Packet extraction
* Circular RAM buffering
* Continuous TS regeneration
* Automatic NULL packet insertion (PID `0x1FFF`)
* Buffer occupancy management

### Error Handling

* Transport stream synchronization errors
* Continuity counter errors
* Invalid T2-MI packet detection
* Header validation failures
* CRC verification failures
* Parser recovery and resynchronization

---

## Module Description

### t2mi_to_ts_top

Top-level integration module connecting the TS parser and T2-MI parser.

#### Responsibilities

* Receives incoming MPEG-TS packets
* Routes valid T2-MI payloads to the T2-MI parser
* Handles control and status signaling between modules
* Outputs reconstructed transport stream packets

---

### ts_parser

Extracts T2-MI data from MPEG Transport Stream packets.

#### Functions

* Synchronization on TS packet boundaries
* PID filtering
* Continuity counter tracking
* Adaptation field parsing
* Pointer field processing
* Payload extraction
* T2-MI packet forwarding

#### State Machine

| State              | Description                                     |
| ------------------ | ----------------------------------------------- |
| SYNC               | Wait for TS sync byte                           |
| PID_H              | Read PID high byte                              |
| PID_L              | Read PID low byte                               |
| CC_AFC             | Continuity counter and adaptation field control |
| ADAPTATION_LENGTH  | Read adaptation field length                    |
| ADAPTATION_FIELD   | Skip adaptation bytes                           |
| POINTER_FIELD      | Read pointer field                              |
| POINTER_SECTION    | Skip pointer bytes                              |
| PAYLOAD            | Forward payload                                 |
| T2MI_RECEIVE_SKIP  | Handle skip request                             |
| T2MI_RECEIVE_ERROR | Handle parser error                             |
| T2MI_SEND_ERROR    | Signal error                                    |

---

### t2mi_parser

Processes DVB-T2 T2-MI Baseband Frame packets and reconstructs TS packets.

#### Functions

* T2-MI header parsing
* DVB-T2 CRC-8 verification
* BBFRAME payload extraction
* SYNCD processing
* Baseband padding removal
* TS packet buffering
* TS reconstruction

#### Main State Machine

| State             | Description                |
| ----------------- | -------------------------- |
| HDR               | Parse T2-MI header         |
| SYNCD_SKIP        | Skip synchronization bytes |
| UP                | Process user packets       |
| BBPADDING         | Skip baseband padding      |
| CRC32             | Skip CRC32 field           |
| TSP_RECEIVE_ERROR | Upstream error handling    |
| TSP_SEND_SKIP     | Skip packet                |
| TSP_SEND_ERROR    | Report error               |

#### RAM Read State Machine

| State            | Description                  |
| ---------------- | ---------------------------- |
| SYNC             | Emit TS sync byte            |
| RD_PCK           | Read packet from RAM         |
| NULL_PCK_PID_H   | Generate NULL PID high byte  |
| NULL_PCK_PID_L   | Generate NULL PID low byte   |
| NULL_PCK_CC_AFC  | Generate NULL packet header  |
| NULL_PCK_PAYLOAD | Generate NULL packet payload |

---

## Interfaces

### Input Transport Stream

| Signal     | Width | Description               |
| ---------- | ----- | ------------------------- |
| ts_clk_i   | 1     | TS byte clock             |
| ts_sync_i  | 1     | TS packet synchronization |
| ts_valid_i | 1     | Valid byte indicator      |
| ts_data_i  | 8     | TS data byte              |

### PID Selection

| Signal                   | Width | Description         |
| ------------------------ | ----- | ------------------- |
| ts_target_pid_i          | 13    | Target T2-MI PID    |
| ts_target_pid_received_i | 1     | PID valid indicator |

### Output Transport Stream

| Signal       | Width | Description                   |
| ------------ | ----- | ----------------------------- |
| tsup_clk_o   | 1     | Output TS clock               |
| tsup_sync_o  | 1     | Output packet synchronization |
| tsup_valid_o | 1     | Output byte valid             |
| tsup_data_o  | 8     | Output TS byte                |

---

## Requirements

### Supported Standards

* DVB-T2
* T2-MI Baseband Frame packets
* MPEG-2 Transport Stream

### FPGA Resources

The design requires:

* Block RAM for TS packet buffering
* Synchronous logic for parser state machines
* Byte-oriented TS interfaces

The exact resource utilization depends on the target FPGA family and synthesis options.

---

## Integration

Instantiate the top-level module:

```vhdl
u_t2mi_to_ts : entity work.t2mi_to_ts_top
port map (
    clk_i                    => clk,
    rst_i                    => rst,

    ts_clk_i                 => ts_clk,
    ts_sync_i                => ts_sync,
    ts_valid_i               => ts_valid,
    ts_data_i                => ts_data,

    ts_target_pid_i          => target_pid,
    ts_target_pid_received_i => pid_valid,

    tsup_clk_o               => tsup_clk,
    tsup_sync_o              => tsup_sync,
    tsup_valid_o             => tsup_valid,
    tsup_data_o              => tsup_data
);
```

---

## Limitations

* Supports DVB-T2 Baseband Frame packets (Packet Type `0x00`)
* Single target PID at a time
* Assumes byte-synchronous transport stream input
* CRC32 field is skipped but not verified
* Designed for FPGA-based streaming applications

---

## Verification

Recommended verification steps:

1. Feed a transport stream containing T2-MI packets.
2. Configure the target PID carrying the T2-MI stream.
3. Verify TS synchronization and PID filtering.
4. Verify successful BBFRAME extraction.
5. Verify reconstructed TS packet output.
6. Verify NULL packet insertion under low-buffer conditions.
7. Test error recovery scenarios.

---

## Author

**Xabier Legaspi Juanatey**

Date: 2026-06-04

---

## License

This project is provided as-is for educational, research, and development purposes.

Please add an appropriate open-source or commercial license before distribution.

