# A MIDI driver for Java, using the standard javax.sound API
# Requires JRuby.
#
# As of 2010 this driver should be fully cross platform.
# OS X 10.5+ users need to be running Java version 1.5.0_22 or higher.
#
# == Authors
#
# * Adam Murray <adam@compusition.com>
#
# == Copyright
#
# Copyright (c) 2010 Adam Murray
#
# This code released under the terms of the MIT license.
#
class MIDIator::Driver::JavaSound < MIDIator::Driver # :nodoc:
  require 'java'
  include_package 'javax.sound.midi'
  
  def initialize
    refresh
    at_exit { close } # bad things can happen if you don't always close your java sound devices
  end
  
  # Refreshes the list of output devices. 
  # You can call this if you plug in a device while the program is running.
  def refresh
    (@outputs ||= []).clear
    MidiSystem.getMidiDeviceInfo.each do |device_info| 
      device = MidiSystem.getMidiDevice(device_info)
      if device.maxReceivers != 0 # then this is an output
        @outputs << device
      end
    end
  end
  
  # Get all output device descriptions
  # This is the text that will be matched against when searching for an output device (see the outpu method below)
  def output_descriptions
    @outputs.collect{|output| output.device_info.description }
  end
  
  # Find an output by a descriptor
  # Numbers are assumed to be indexes into output list
  # Everything else is converted to a regular expression and used to find the first matching device description
  def output( descriptor = 0 )
    if descriptor.is_a? Numeric
      @outputs[descriptor]
    else
      descriptor = Regexp.new(descriptor.to_s) unless descriptor.is_a? Regexp
      @outputs.find{ |output| output.device_info.description =~ descriptor }
    end
  end
  
  def open( output_descriptor = 0 )
    new_output = output(output_descriptor)
    raise "output #{output_descriptor} not found" unless new_output
    close unless new_output == @output # close previously opened output
    @output = new_output
    @output.open unless @output.open?    

    # Some output devices may have multiple receivers but we just use the 
    # first one. Things could definitely be made more flexible...
    @receiver = @output.receiver
  end
  
  # expose the underlying java sound device in case the containing program wants to use it
  def device
    @output
  end
  
  def message( *args )
    midi_message = ByteArrayMessage.new(*args)    
    # Use java_send to call Receiver.send() since it conflicts with Ruby's built-in send method
    @receiver.java_send :send, [MidiMessage, Java::long], midi_message, -1
  end
  
  def close
    @output.close if @output and @output.open?    
  end  
  
  # A wrapper around ShortMessage that exposes the protected byte[] constructor
  class ByteArrayMessage < ShortMessage
    def initialize( *args )
      super( args.to_java(:byte) )
    end
  end    
  
end