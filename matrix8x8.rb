#!/usr/bin/env ruby
#
# Copyright (c) 2012, Sungjin Han <meinside@gmail.com> (Matrix8x8)
# All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of meinside nor the names of its contributors may be
#    used to endorse or promote products derived from this software without
#    specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
#  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.
#

require "i2c/i2c"
require "i2c/backends/i2c-dev"

class Matrix8x8
  # Registers
  HT16K33_REGISTER_DISPLAY_SETUP = 0x80
  HT16K33_REGISTER_SYSTEM_SETUP  = 0x20
  HT16K33_REGISTER_DIMMING       = 0xE0

  # Blink rate
  HT16K33_BLINKRATE_OFF          = 0x00
  HT16K33_BLINKRATE_2HZ          = 0x01
  HT16K33_BLINKRATE_1HZ          = 0x02
  HT16K33_BLINKRATE_HALFHZ       = 0x03

  MAX_COL = 8
  MAX_ROW = 8

  attr_accessor :device, :address

  def self.board_revision
    File.open("/proc/cpuinfo", "r"){|file|
      return ["2", "3"].include?(file.each_line.find{|x| x =~ /^Revision/ }
        .strip[-1]) ? 1 : 2
    }
  end

  def self.i2c_device_path
    case self.board_revision
    when 1
      return "/dev/i2c-0"
    when 2
      return "/dev/i2c-1"
    end
  end

  def initialize(device = self.i2c_device_path, address = 0x70,
  options = {blink_rate: HT16K33_BLINKRATE_OFF, brightness: 15})
    if device.kind_of? String
      @device = ::I2C.create(device)
    else
      [ :read, :write ].each do |m|
        raise IncompatibleDeviceException,
        "Missing #{m} method in device object." unless device.respond_to?(m)
      end
      @device = device
    end
    @address = address

    # turn on oscillator
    @device.write(@address, HT16K33_REGISTER_SYSTEM_SETUP | 0x01, 0x00, 0x00)

    # set blink rate and brightness
    set_blink_rate(options[:blink_rate])
    set_brightness(options[:brightness])

    if block_given?
      yield self
    end
  end

  def set_blink_rate(rate)
    rate = HT16K33_BLINKRATE_OFF if rate > HT16K33_BLINKRATE_HALFHZ
    @device.write(@address, HT16K33_REGISTER_DISPLAY_SETUP | 0x01 | (rate << 1),
      0x00, 0x00)
  end

  def set_brightness(brightness)
    brightness = 15 if brightness > 15
    @device.write(@address, HT16K33_REGISTER_DIMMING | brightness, 0x00, 0x00)
  end

  def clear
    (0...MAX_ROW).each{|n| write(n, 0x00, 0x00) }
  end

  def fill
    (0...MAX_ROW).each{|n| write(n, 0xFF, 0xFF) }
  end

  def write(row, value, value2)
    @device.write(@address, row * 2, value)
    @device.write(@address, row * 2 + 1, value2)
  end

  def read(row)
    @device.read(@address, 2, row * 2).unpack("C*")
  end
end
