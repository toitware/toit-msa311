# MSA311

Toit driver for the MSA311 accelerometer.

## Usage

A simple usage example.

```
import gpio
import i2c
import msa311

main:
  bus := i2c.Bus
    --sda=gpio.Pin 21
    --scl=gpio.Pin 22

  device := bus.device msa311.I2C_ADDRESS
  sensor := msa311.Msa311 device

  sensor.enable
  print sensor.read_acceleration
```

See the `examples` folder for more examples.

## References

Datasheet for the MSA311: https://cdn-shop.adafruit.com/product-files/5309/MSA311-V1.1-ENG.pdf

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/toitware/toit-msa311/issues
