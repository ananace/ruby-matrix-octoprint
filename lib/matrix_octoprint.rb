# frozen_string_literal: true

require_relative 'matrix_octoprint/matrix_client'
require_relative 'matrix_octoprint/octoprint_client'
require_relative 'matrix_octoprint/util'
require_relative 'matrix_octoprint/version'

module MatrixOctoprint
  class Error < StandardError; end

  def self.matrix
    @matrix ||= MatrixClient.new
  end

  def self.octoprint
    @octoprint ||= OctoprintClient.new
  end
end
