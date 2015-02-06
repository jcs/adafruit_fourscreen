#!/usr/bin/env ruby

require_relative "matrix8x8"
require_relative "font3x5"

class FourScreen
  SC_ADDR_1 = 0x74
  SC_ADDR_2 = 0x71
  SC_ADDR_3 = 0x72
  SC_ADDR_4 = 0x70

  SC_ADDRS = [ SC_ADDR_4, SC_ADDR_3, SC_ADDR_2, SC_ADDR_1 ]

  SC_WIDTH = 8
  SC_HEIGHT = 8

  OFF = 0
  GREEN = 1
  RED = 2
  YELLOW = 3

  attr_accessor :screens, :matrix

  def initialize
    @screens = SC_ADDRS.map{|addr|
      Matrix8x8.new(Matrix8x8.i2c_device_path, addr)
    }

    clear(true)
    read
  end

  def set_brightness(level)
    @screens.each{|s| s.set_brightness(level) }
  end

  def clear(screen = false)
    if screen
      @screens.each{|s| s.clear }
    end
    @matrix = SC_HEIGHT.times.map{ Array.new(SC_WIDTH * SC_ADDRS.count, OFF) }
  end

  def read
    @screens.each_with_index do |screen,x|
      SC_WIDTH.times do |row|
        vals = screen.read(row)

        # 20 -> "10100" -> [ 1, 0, 1, 0, 0 ]
        bits = vals[0].to_s(2).split("").map{|i| i.to_i }
        bits2 = vals[1].to_s(2).split("").map{|i| i.to_i }

        # [ 1, 0, 1, 0, 0 ] -> [ 0, 0, 0, 0, 0, 1, 0, 1 ]
        while bits.length < SC_WIDTH
          bits.unshift 0
        end
        while bits2.length < SC_WIDTH
          bits2.unshift 0
        end
        bits.reverse!
        bits2.reverse!

        actual_row = (x * SC_WIDTH) + (SC_WIDTH - row) - 1
        SC_WIDTH.times do |y|
          if bits[y] == 1 && bits2[y] == 1
            v = YELLOW
          elsif bits[y] == 1 && bits2[y] == 0
            v = GREEN
          elsif bits[y] == 0 && bits2[y] == 1
            v = RED
          else
            v = OFF
          end

          if @matrix[y][actual_row] != v
            raise "expected #{y}x#{actual_row} to be #{v}, is " <<
              "#{@matrix[y][actual_row]}"
          end

          @matrix[y][actual_row] = v
        end
      end
    end
  end

  def to_s
    o = ""
    @matrix.each do |row|
      row.each do |x|
        if x == OFF
          o << "."
        elsif x == GREEN
          o << "G"
        elsif x == RED
          o << "R"
        elsif x == YELLOW
          o << "Y"
        end
      end
      o << "\n"
    end
    o
  end

  def set(col, row, val)
    @matrix[row][col] = val
  end

  def set_brightness(val)
    @screens.each{|s| s.set_brightness(val) }
  end

  def write
    @screens.each_with_index do |screen,x|
      SC_WIDTH.times do |col|
        val = ""
        val2 = ""
        SC_HEIGHT.times do |row|
          case @matrix[row][col + (x * SC_WIDTH)]
          when OFF
            val << "0"
            val2 << "0"
          when GREEN
            val << "1"
            val2 << "0"
          when RED
            val << "0"
            val2 << "1"
          when YELLOW
            val << "1"
            val2 << "1"
          end
        end

        # "001010101" -> "101010100" -> 340
        val = val.reverse.to_i(2)
        val2 = val2.reverse.to_i(2)

        row = SC_WIDTH - col - 1

        screen.write(row, val, val2)
      end
    end
  end

  def draw_word(x, text, color)
    text.to_s.each_char do |char|
      col_size = 0

      Font3x5::CHARS[char.ord].each_with_index do |cbits,row|
        cbits.each_with_index do |bit,col|
          self.set(x + col, row + 1, bit == 1 ? color : 0)
          col_size = col
        end
      end

      x += col_size + 2
    end

    x
  end

  def height
    SC_HEIGHT
  end

  def width
    SC_WIDTH * @screens.count
  end
end
