# GeodesicTempo

This script is a tool that adds periodic rhythmic fluctuations to quantized MIDI notes by modulating the time axis. Since real-time processing cannot output notes ahead of time, it creates relative acceleration and deceleration by applying a pre-delay to all events.

**Note:** It is designed with the assumption that the value displayed in **Latency** will be negatively compensated on the DAW side.

## Requirements
* **UVI Scripting Engine** (UVI Falcon, etc.)

## How to Use
1. **Load the script:** In UVI Falcon, go to the **Events** tab, add a **Script Processor**, and load this script.
2. Check the value displayed in the **Latency** box.
3. In your DAW, set the **Track Delay** for that track to the negative of that value (e.g., if Latency is 125ms, set Track Delay to -125ms).

## Parameters
* **Cycle**: Selects the duration of one modulation cycle (from 1/16 to 1/1).
* **Mode**: Choose from four timing patterns (Pull-Pull, Push-Push, Pull-Push, Push-Pull).
* **Curve**: Defines the shape of the modulation curve, from linear to various exponential powers.
* **Amount**: Adjusts the overall intensity of the rhythmic fluctuation.
* **Asymmetry**: Shifts the peak of the modulation within the cycle for "skewed" patterns.
* **Invert**: Flips the phase of the LFO, reversing the timing shifts.
* **NoteLength**: 
    * **Fixed (Stable)**: Maintains a constant duration based on the Note-On offset.
    * **Flex (Dynamic)**: Calculates the offset at the moment of release for dynamic length changes.
* **Latency**: Displays the current maximum delay in milliseconds for DAW track delay compensation.
* **Tension**: Real-time visual feedback of the current modulation state.

## License
MIT License
