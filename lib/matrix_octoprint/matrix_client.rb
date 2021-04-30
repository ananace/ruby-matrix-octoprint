# frozen_string_literal: true

require 'matrix_sdk'

module MatrixOctoprint
  class MatrixClient
    attr_reader :thread, :client, :rooms

    def connect(uri, user: nil, password: nil, token: nil, rooms: nil, type: nil)
      @client = if token
                  MatrixSdk::Client.new uri, access_token: token
                else
                  MatrixSdk::Client.new uri
                end

      client.login user, password, no_sync: true unless token

      if rooms
        @rooms = rooms.map { |r| client.join_room(r) }
      else
        client.reload_rooms!
        @rooms = client.rooms
      end
      @type = type

      # @thread = client.start_listen_thread
    end

    def disconnect
      @rooms = nil
      @client = nil
    end

    def logger
      @logger ||= Logging.logger[self]
    end

    def send(bare:, html: nil, type: nil, room: nil, data: nil)
      msg_data = {
        body: bare,
        format: html ? 'org.matrix.custom.html' : nil,
        formatted_body: html,
        msgtype: type || @type,

        'org.octoprint.data': data
      }.compact

      rooms.each do |r|
        next if room && r != room && r.id != room

        client.api.send_message_event(r.id, 'm.room.message', msg_data)
      end
    end
  end
end
