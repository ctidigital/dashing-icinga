require 'addressable/uri'
require 'net/http'
require 'json'

#
# Hard coded configuration variables - should not be updated unless you know what you are doing
#
yamlFile = "./icinga.yml"
serviceStateMap = %w(OK WARNING CRITICAL UNKNOWN)
hostStateMap = %w(UP DOWN UNREACHABLE PENDING)

if File.exist?(yamlFile)
    config = YAML.load(File.new(yamlFile, "r").read)
    configuration = config[:icinga]
else
    configuration = {
        :base_uri => '',
        :authkey => '',
        :refresh_rate => '30s',
    }
end

class IcingaRequest
  attr_accessor :host,
                :authkey,
                :target,
                :filter,
                :columns,
                :column_count,
                :order,
                :output

  def initialize(params)
    @host = params[:host]
    @target = params[:target]
    @filter = params[:filter]
    @columns = params[:columns]
    @column_count = params[:column_count]
    @order = params[:order]
    @authkey = params[:authkey]
    @output = params[:output]
  end

  def get
    uri = Addressable::URI.parse to_url
#
# For some reason, addressable does not set the port to 443 by default for https:// urls
# Work around that here - add a catchall for http and https
#
    if uri.port.nil?
      if uri.scheme == 'https'
        uri.port = 443
      elsif uri.scheme == 'http'
        uri.port = 80
      end
    end
    req = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      req.use_ssl = true
    end
    res = req.get(uri.request_uri)
    res.code == '200' ? res.body : ''
  end

#
# Build the URL to access Icinga with
#
  def to_url
    "%s/web/api/%s/%s/authkey=%s/%s" % [ host, target, url_options, authkey, output ]
  end

#
# Build the optional part of the URL
#
  def url_options
    [ filter_url, columns_url, order_url, column_count_url].compact.join('/')
  end

  def filter_url
    self.filter ? "filter[%s]" % filter : nil
  end

  def columns_url
    self.columns ? "columns[%s]" % columns.join('|') : nil
  end

  def order_url
    self.order ? "order(%s)" % order.join('|') : nil
  end

  def column_count_url
    self.column_count ? "countColumn=%s" % count_column : nil
  end
end

def count_summary(req, stateMap)

  objs = JSON.load(req.get)

  states = Hash.new( :value => 0 )
  stateMap.each do |state|
    states[state] = { label: state, value: 0 }
  end

  objs['result'].each do |res|
    lState = stateMap[ res['SERVICE_CURRENT_STATE'].to_i ]
    states[ lState ] = { label: lState, value: (states[lState][:value] + 1) }
  end
  err = 0
  tot = 0
  stateMap.each do |state|
    if state != 'OK' and state != 'UP'
      err = err + states[state][:value]
    end
    tot = tot + states[state][:value]
  end
  states['Total'] = { label: 'Total', value: "%d / %d" % [ err, tot ] }
  return states
end

SCHEDULER.every configuration[:refresh_rate] do

  serviceReq = IcingaRequest.new( 
      :host => configuration[:base_url],
      :target => 'service',
      :authkey => configuration[:authkey],
      :columns =>  ['SERVICE_NAME',
                    'HOST_NAME',
                    'SERVICE_CURRENT_STATE',
                    'HOST_CURRENT_STATE',
                    'SERVICE_ID' ],
      :order => [ 'SERVICE_ID;DESC' ],
      :count_column => 'SERVICE_ID',
      :output => 'json'
  )

  serviceStates = count_summary(serviceReq, serviceStateMap)

  hostReq = IcingaRequest.new( 
      :host => configuration[:base_url],
      :target => 'host',
      :authkey => configuration[:authkey],
      :columns =>  ['HOST_NAME',
                    'HOST_CURRENT_STATE',
                    'HOST_ID' ],
      :order => [ 'HOST_ID;DESC' ],
      :count_column => 'HOST_ID',
      :output => 'json'
  )

  hostStates = count_summary(hostReq, hostStateMap)

  send_event( 'icinga_host_status', { hosts: hostStates } )
  send_event( 'icinga_service_status', { services: serviceStates } )

end 
