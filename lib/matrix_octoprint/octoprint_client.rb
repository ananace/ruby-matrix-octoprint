# frozen_string_literal: true

require 'matrix_octoprint/octoprint_client/templates'

require 'erb'
require 'securerandom'
require 'faye/websocket'

module MatrixOctoprint
  class OctoprintClient
    attr_reader :base_uri, :session, :thread, :ws, :ws_uri

    def connect(uri, user: nil, password: nil, apikey: nil)
      @base_uri = uri
      @user = user
      @password = password
      @apikey = apikey

      @session = if apikey
                   api_request(:POST, :login, passive: true)
                 else
                   api_request(:POST, :login, user: user, pass: password)
                 end

      @ws_uri = base_uri.dup.tap do |ws_uri|
        ws_uri.scheme = if ws_uri.scheme == 'https'
                          'wss'
                        else
                          'ws'
                        end
        ws_uri.path = "/sockjs/#{format('%03d', rand(999))}/#{SecureRandom.uuid}/websocket"
      end

      @thread = Thread.new do
        EventMachine.run do
          connect_ws
        end
      end
    end

    def disconnect
      logger.info 'Disconnecting from Octoprint'
      ws.close

      api_request :POST, :logout
    end

    def logger
      @logger ||= Logging.logger[self]
    end

    private

    def connect_ws
      logger.info 'Connecting to Octoprint websocket API'
      @ws = Faye::WebSocket::Client.new ws_uri.to_s

      ws.on :open do |_event|
        logger.info 'Established websocket connection to Octoprint'
      end

      ws.on :message do |event|
        # logger.debug "Received message #{event.data.inspect}"

        JSON.parse(event.data[1..]).each { |ev| ev.each { |k, v| handle_message(k, v) } } if event.data[0] == 'a'
        JSON.parse(event.data[1..]).each { |k, v| handle_message(k, v) } if event.data[0] == 'm'
      rescue StandardError => e
        logger.error "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      end

      ws.on :close do |event|
        logger.info "Lost websocket connection to Octoprint: #{event.inspect}"
      end
    end

    def run_timer(interval, &block)
      EventMachine::Timer.new(interval) { timer_elapsed(interval, block) }
    end

    def timer_elapsed(interval, &block)
      return unless block.call

      run_timer(interval, block)
    end

    def post_job_update
      job = api_request(:GET, :job) rescue { 'job' => {} }
      job = DeepOpenStruct.new(job['job'])

      return false if %w[Operational Error Offline].include? job.state

      MatrixOctoprint.matrix.send(
        replace: 'job message',
        html: Templates.render(:print_update, :html).result(binding),
        bare: Templates.render(:print_update, :md).result(binding),

        data: job
      )

      true # Continue to loop
    end

    def handle_message(type, data)
      logger.debug "Received #{type} message"

      method = "_handle_#{type}".to_sym
      send method, data if private_methods.include? method
    end

    def _handle_connected(_data)
      logger.info 'Sending authentication information to Octoprint'

      ws_send({ auth: "#{session['name']}:#{session['session']}" })
      ws_send({ throttle: 10 }) # Message every 5 seconds
    end

    def _handle_reauthRequired(data)
      logger.info 'Reauthenticating to Octoprint'

      @session = if %w[logout removed].include?(data['reason'])
                   api_request(:POST, :login, passive: true)
                 else
                   api_request(:POST, :login, user: user, pass: password)
                 end

      ws_send({ auth: "#{session['name']}:#{session['session']}" })
    end

    def _handle_event(data)
      logger.debug "Handling #{data['type']} event"
      method = "_handle_event_#{data['type']}".to_sym
      send method, data['payload'] if private_methods.include? method
    end

    def _handle_event_PrintStarted(event)
      event = DeepOpenStruct.new(event)
      job = api_request(:GET, :job) rescue { 'job' => {} }
      job = DeepOpenStruct.new(job['job'])

      logger.debug "PrintStarted\nevent: #{event.inspect}\njob: #{job.inspect}"

      MatrixOctoprint.matrix.send(
        html: Templates.render(:print_start, :html).result(binding),
        bare: Templates.render(:print_start, :md).result(binding),

        data: job.to_h
      )

      run_timer(30 * 60) { post_job_update }
    end

    def _handle_event_PrintFailed(data); end

    def _handle_event_PrintDone(event)
      event = DeepOpenStruct.new(event)
      MatrixOctoprint.matrix.send(
        # html: Templates.render(:print_done, :html).result(binding),
        bare: Templates.render(:print_done, :md).result(binding)
      )
    end

    def _handle_event_PrintCancelling(data); end

    def _handle_event_PrintCancelled(data); end

    def _handle_event_PrintPaused(data); end

    def _handle_event_PrintResumed(data); end

    def ws_send(data)
      logger.debug "WS< #{data.inspect}"

      # WTF SockJS?!
      data = [data.to_json]
      data = data.to_json
      ws.send data
    end

    def api_request(method, path, parameters = nil)
      logger.debug "< #{method.to_s.upcase} #{path}"

      uri = base_uri.dup.tap do |api_uri|
        api_uri.path = File.join '/api', path.to_s
      end
      req = Net::HTTP.const_get(method.to_s.capitalize.to_sym).new uri.request_uri
      if parameters
        req.body = parameters.to_json
        req.content_type = 'application/json'
      end
      req['authorization'] = "Bearer #{@apikey}" if @apikey

      response = http.request req
      logger.debug "> #{response.class} #{response}"
      response.value

      JSON.parse(response.body)
    rescue JSON::JSONError
      response
    end

    def http
      return @http if @http&.active?

      @http ||= Net::HTTP.new base_uri.host, base_uri.port
      @http.use_ssl = base_uri.scheme == 'https'
      @http.start
      @http
    end
  end
end
