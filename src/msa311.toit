// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

/**
Driver for the MSA311 accelerometer.

Datasheet: https://cdn-shop.adafruit.com/product-files/5309/MSA311-V1.1-ENG.pdf
*/

import binary
import math
import serial.device as serial
import serial.registers as serial

I2C_ADDRESS     ::= 0x62
I2C_ADDRESS_ALT ::= 0x63

/**
Driver for the MSA311 accelerometer.
*/
class Msa311:
  /*
  1Hz and 1.95Hz are only available in low-power mode.
  static RATE_1HZ     ::= 0
  static RATE_1_95HZ  ::= 1
  */
  static RATE_3_9HZ   ::= 2
  static RATE_7_81HZ  ::= 3
  static RATE_15_63HZ ::= 4
  static RATE_31_25HZ ::= 5
  static RATE_62_5HZ  ::= 6
  static RATE_125HZ   ::= 7
  static RATE_250HZ   ::= 8
  static RATE_500HZ   ::= 9
  static RATE_1000HZ  ::= 10

  static RANGE_2G  ::= 0
  static RANGE_4G  ::= 1
  static RANGE_8G  ::= 2
  static RANGE_16G ::= 3

  static CHIP_ID_         ::=  0x13
  // Device Registers.
  static REG_SOFT_RESET_ ::= 0x00
  static REG_WHO_AM_I_   ::= 0x01
  static REG_RANGE_      ::= 0x0F
  static REG_ODR_        ::= 0x10
  static REG_POWER_      ::= 0x11

  static ACC_X_L_ ::= 0x02
  static ACC_X_H_ ::= 0x03
  static ACC_Y_L_ ::= 0x04
  static ACC_Y_H_ ::= 0x05
  static ACC_Z_L_ ::= 0x06
  static ACC_Z_H_ ::= 0x07


  static GRAVITY_STANDARD_ ::= 9.80665

  // The currently selected range.
  range_/int := 0

  reg_/serial.Registers ::= ?

  constructor dev/serial.Device:
    reg_ = dev.registers
    // Check chip ID
    if (reg_.read_u8 REG_WHO_AM_I_) != CHIP_ID_: throw "INVALID_CHIP"

  /**
  Enables the sensor.
  The $rate parameter defines the frequency at which measurements are taken.
  Valid values for $rate are:
  - $RATE_3_9HZ
  - $RATE_7_81HZ
  - $RATE_15_63HZ
  - $RATE_31_25HZ
  - $RATE_62_5HZ
  - $RATE_125HZ
  - $RATE_250HZ
  - $RATE_500HZ
  - $RATE_1000HZ

  The $range parameter defines the maximum +/- range (in g).
  Valid values for $range are:
  - $RANGE_2G: +-2G (19.61 m/s²)
  - $RANGE_4G: +-4G (39.23 m/s²)
  - $RANGE_8G: +-8G (78.45 m/s²)
  - $RANGE_16G: +-16G (156.9 m/s²)
  */
  enable -> none
      --rate/int = RATE_15_63HZ
      --range/int = RANGE_2G:

    if not RATE_3_9HZ <= rate <= RATE_1000HZ: throw "INVALID_RANGE"

    // We always enable all three axes.
    axes_bits := 0b111 << 5

    odr_bits := axes_bits | rate

    if not RANGE_2G <= range <= RANGE_16G: throw "INVALID_RANGE"
    range_ = range

    reg_.write_u8 REG_SOFT_RESET_ 1
    reg_.write_u8 REG_ODR_ odr_bits
    reg_.write_u8 REG_RANGE_ range
    reg_.write_u8 REG_POWER_ 0x00

  /**
  Disables the accelerometer.
  Initiates a power-down of the peripheral. It is safe to call $enable
    to restart the accelerometer.
  */
  disable:
    // Fundamentally we only care for the rate-bits: as long as they
    // are 0, the device is disabled.
    // It's safe to change the other bits as well.
    reg_.write_u8 REG_POWER_ 0b1100_0000

  /**
  Reads the acceleration on the x, y and z axis.
  The returned values are in in m/s².
  */
  read_acceleration -> math.Point3f:
    x := reg_.read_i16_le ACC_X_L_
    y := reg_.read_i16_le ACC_Y_L_
    z := reg_.read_i16_le ACC_Z_L_

    // At this point the top 12 bits have the correct values in it.

    // Section 2.2, table3:
    // The linear acceleration sensitivity depends on the range.
    // - RANGE_2G:   1024 LSB/g
    // - RANGE_4G:   512  LSB/g
    // - RANGE_8G:   256  LSB/g
    // - RANGE_16G:  128  LSB/g
    // Shift the bits down depending on the range.
    x >>= 3 - range_
    y >>= 3 - range_
    z >>= 3 - range_

    // Now each variable has 128 LSB/g in the first 12 bits.
    // Divide by 128 for the LSB and divide by 16 to shift the 12 bits to the right.
    factor := GRAVITY_STANDARD_ / 128 / 16 // Constant folded because it's one expression.

    return math.Point3f
        x * factor
        y * factor
        z * factor

