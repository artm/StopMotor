require 'spec_helper'
require 'stopmotor'

describe StopMotor do
  before do
    @sm = StopMotor.new
    @sm.line_step = 5
    @sm.line = 1
    @sm.pos = [0,0,0]
    @sm.lerp_step = 1
    @sm.up = 1
    @sm.down = -1
    @sm.home = [-1,-1,1]
  end

  it 'renumbers lines' do
    output = ''
    @sm.process('N0001 G90'){ |line| output = line }
    output.should == 'N0001 G90'
    @sm.process('N0003 M08'){ |line| output = line }
    output.should == 'N0006 M08'
  end

  it 'does not touch comments' do
    output = ''
    @sm.process('(Comment)'){ |line| output = line }
    output.should == '(Comment)'
    @sm.process('N0001 G90'){ |line| output = line }
    output.should == 'N0001 G90'
    @sm.process('(Comment)'){ |line| output = line }
    output.should == '(Comment)'
    @sm.process('N0003 M08'){ |line| output = line }
    output.should == 'N0006 M08'
  end

  it "can parse XYZ" do
    @sm.parse_xyz(["X1.0000","Y2.0000","Z3.456"]).should be_within(1e-5).of([1,2,3.456])
    expect { @sm.parse_xyz ["Y2.000", "Z3.000", "X4.000"] }.to raise_exception
    expect { @sm.parse_xyz ["Xfoo", "Ybar", "Zbaz"] }.to raise_exception
  end

  it 'maintains current position on G00' do
    @sm.process('N0001 G00 X1.0000 Y2.0000 Z3.0000 F500'){}
    @sm.pos.should be_within(1e-5).of([1,2,3])
  end

  it 'does not split vertical lines on G01' do
    @sm.pos = [1,2,1]
    @sm.stub(:split_lerp).and_raise('Should not split vertical lines')
    commands = []
    @sm.process('N0003 G01 X1.0000 Y2.0000 Z-1.0000 F500') { |line| commands << line }
    commands.should have(1).item
    commands[0].should match /G01 X1.0000 Y2.0000 Z-1.0000 F500/
  end

  it 'splits lines on G01' do
    @sm.pos = [1,2,-1]
    @sm.should_receive(:split_lerp).with(any_args) do |from,to,step|
      from.should be_within(1e-5).of([1,2,-1])
      to.should be_within(1e-5).of([10,2,-1])
      step.should be_within(1e-5).of(@sm.lerp_step)
    end
    @sm.process('N0003 G01 X10.0000 Y2.0000 Z-1.0000 F500') { }
  end

  it 'passes feed rate on split lerps' do
    @sm.pos = [1,2,-1]
    passed = false
    @sm.process('N0003 G01 X10.0000 Y2.0000 Z-1.0000 F1500') do |cmd|
      if /G01/ =~ cmd
        passed = /F1500/ =~ cmd
        break
      end
    end
    passed.should be_true
  end

  it "splits straight lines into steps" do
    start = [0,0,-1]
    finish = [5, 0, -1]

    steps = []
    @sm.split_lerp(start, finish, 1) do |*point|
      steps << point
    end

    steps.should have(5).items
    (1..5).each_with_index { |x,i| steps[i].should == [x,0,-1] }
  end

  it 'calls insert_loop for each lerp step' do
    @sm.pos = [1,2,-1]
    @sm.should_receive(:insert_loop).exactly(9).times
    @sm.process('N0003 G01 X10.0000 Y2.0000 Z-1.0000 F500') { }
  end

  describe 'make_command' do
    it 'supports :goto' do
      cmd = @sm.make_command :goto, 1, 2, 3
      cmd.should match /^N0+1 G00 X1\.0+ Y2\.0+ Z3\.0+/
      @sm.pos.should be_within(1e-5).of([1,2,3])
    end
    it 'supports :up' do
      @sm.make_command :up
      @sm.pos.should be_within(1e-5).of([0,0,1])
    end
    it 'supports :down' do
      @sm.make_command :down
      @sm.pos.should be_within(1e-5).of([0,0,-1])
    end
    it 'supports :home' do
      @sm.make_command :home
      @sm.pos.should be_within(1e-5).of(@sm.home)
    end
    it 'supports :dwell' do
      cmd = @sm.make_command :dwell, 1000
      cmd.should match /G04 P1000/
      expect{@sm.make_command :dwell}.to raise_exception
    end
    it 'supports :lerp' do
      cmd = @sm.make_command :lerp, 1, 2, 3
      cmd.should match /^N0+1 G01 X1\.0+ Y2\.0+ Z3\.0+/
      @sm.pos.should be_within(1e-5).of([1,2,3])

      cmd = @sm.make_command :lerp, 1, 2, 3, "F1500"
      cmd.should match /^N0+6 G01 X1\.0+ Y2\.0+ Z3\.0+ F1500/
    end
  end

  it 'reaches the destination after insert_loop' do
    @sm.pos = [1,0,-1]
    @sm.insert_loop(2,0,-1){}
    @sm.pos.should be_within(1e-5).of([2,0,-1])
  end

  it 'configures default parameters' do
    sm = StopMotor.new
    sm.line_step.should == 2
    sm.line.should == 1
    sm.lerp_step.should == 1
    sm.up.should == 0.8
    sm.down.should == -0.5
    sm.home.should == [0,0,sm.up]
  end
end
