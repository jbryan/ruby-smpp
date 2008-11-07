#!/usr/bin/env ruby

# Sample SMPP SMS Gateway. 

require 'rubygems'
#gem 'ruby-smpp'
require 'smpp'
require 'smpp/server'

# set up logger
Smpp::Base.logger = Logger.new('smsc.log')

# the transceiver
$tx = nil


def logger
  Smpp::Base.logger
end

class MySmscServer < Smpp::Server
  def process_submit_sm(pdu)
    id = super(pdu)
    #if a delivery report is required
    if (pdu.registered_delivery == 1)
      #randomly pick a status
      stat = [
        "DELIVERED",
        "UNDELIVERABLE",
        "ACCEPTED",
        "REJECTED"
      ].rand

      delivered = (stat == "DELIVERED") ? 1 : 0
      submit_date =  Time.now.strftime("%y%m%d%H%M")
              
      EventMachine::add_timer( rand(10) ) do
        msg = "id:#{id} sub:1 dlvrd:#{delivered} submit date:#{submit_date} " +
              "done date:#{Time.now.strftime("%y%m%d%H%M")} stat:#{stat} err: " +
              "Text:#{pdu.short_message[0..20]}"
        deliver_sm(pdu.destination_addr, pdu.source_addr, msg, { :esm_class => 4 })
      end

    end
    Smpp::Pdu::Base::ESME_ROK
  end
end

def start(config)

  # Run EventMachine in loop so we can reconnect when the SMSC drops our connection.
  loop do
    EventMachine::run do             
      EventMachine::start_server(
          config[:host], 
          config[:port], 
          MySmscServer,
          config
          )       
    end
    logger.warn "Event loop stopped. Restarting in 5 seconds.."
    sleep 5
  end
end

# Start the Gateway
begin   
  puts "Starting SMS Gateway"  

  # SMPP properties. These parameters the ones provided sample_gateway.rb and
  # will work with it.
  config = {
    :host => 'localhost',
    :port => 6000,
    :system_id => 'hugo',
    :password => 'ggoohu',
	  :system_type => 'vma', # default given according to SMPP 3.4 Spec
    :interface_version => 52,
    :source_ton  => 0,
    :source_npi => 1,
    :destination_ton => 1,
    :destination_npi => 1,
    :source_address_range => '',
    :destination_address_range => '',
    :enquire_link_delay_secs => 10,
    :receive_sm_proc => proc { |pdu, id| generate_delivery_reports(pdu, id) }
  }
  start(config)  
rescue Exception => ex
  puts "Exception in SMS Gateway: #{ex} at #{ex.backtrace[0]}"
end
