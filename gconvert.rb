#!/usr/bin/env ruby
require './lib/stopmotor'

sm = StopMotor.new

begin
  ARGF.each do |line|
    sm.process(line.chomp) do |out_line|
      puts out_line
    end
  end
rescue Errno::EPIPE
  # ignore broken pipe
end
