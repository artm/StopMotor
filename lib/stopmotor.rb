class StopMotor
  attr_accessor :line_step, :line, :pos, :lerp_step, :up, :down, :home

  def initialize
    @line_step = 2
    @line = 1
    @lerp_step = 1
    @up = 0.8
    @down = -0.5
    @home = [0,0,@up]
  end

  def next_line
    line = @line
    @line += @line_step
    line
  end

  def next_line_str
    'N%04d' % next_line
  end

  def parse_xyz coords
    axes = "XYZ"
    coords.each_with_index.map do |val,i|
      raise "Bad axis" unless axes[i] == val[0]
      Float(val[1..-1])
    end
  end

  def xyz_str xyz
    "X%0.4f Y%0.4f Z%0.4f" % xyz
  end

  def distance start, finish
    Math.sqrt start.zip(finish).map{ |s,f| (s-f)*(s-f) }.reduce(:+)
  end

  def split_lerp start, finish, step_size
    dist = distance start, finish
    n_steps = (dist / step_size).ceil
    delta = start.zip(finish).map{|s,f| (f-s) / n_steps }
    (1..n_steps).each do |i|
      yield *( start.zip(delta).map{|x,d| x+d*i} )
    end
  end

  def make_command cmd, *args
    case cmd
    when :lerp
      @pos = args[0..2]
      "#{next_line_str} G01 #{xyz_str @pos} #{args[3..-1].join(' ')}"
    when :goto
      @pos = args
      "#{next_line_str} G00 #{xyz_str @pos}"
    when :up
      make_command :goto, @pos[0], @pos[1], @up
    when :down
      make_command :goto, @pos[0], @pos[1], @down
    when :home
      make_command :goto, *@home
    when :dwell
      raise ArgumentError.new "dwell command expects 1 parameter, #{args.count} given" unless args.count==1
      "#{next_line_str} G04 P#{args[0]}"
    else
      raise ArgumentError.new "Unknown command: #{cmd}"
    end
  end

  def insert_loop x,y,z, *rest
    yield make_command :up
    return_pos = @pos
    yield make_command :home
    yield make_command :dwell, 1000
    yield make_command :goto, *return_pos
    yield make_command :down
    yield make_command :lerp, x,y,z, *rest
  end

  def process line, &block
    if /^N\d+ / =~ line
      tokens = line.split
      if /G0(?<lerp>[01])/ =~ tokens[1]
        dest = parse_xyz tokens[2..4]
        if lerp == "1" && @pos[2] < 0.0 && dest[2] < 0.0
          tail = tokens[5..-1]
          split_lerp(@pos, dest, @lerp_step) do |x,y,z|
            insert_loop x,y,z, *tail, &block
            tail = [] # only send tail the first time
          end
        end
      end
      @pos = dest
      yield line.sub(/^N\d+/, next_line_str)
    else
      yield line
    end
  end
end
