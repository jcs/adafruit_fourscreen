#!/usr/bin/env ruby

require "./fourscreen"

fs = FourScreen.new
br = 0
br_dir = :up
while true do
  (8 * 4).times do |x|
    8.times do |y|
      fs.set(x, y, rand(4))
    end
  end
  fs.set_brightness(br)
  fs.write

  if br_dir == :up && br == 15
    br_dir = :down
  elsif br_dir == :down && br == 0
    br_dir = :up
  end

  br += (br_dir == :down ? -1 : 1)
end
