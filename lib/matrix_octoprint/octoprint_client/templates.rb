# frozen_string_literal: true

require 'erb'

module MatrixOctoprint
  class OctoprintClient
    module Templates
      def self.render(template, format)
        ERB.new(load_template(template, format), trim_mode: '-')
      end

      class << self
        private

        def load_template(template, format)
          template_name = "#{template}.#{format}.erb"
          File.read(File.join(__dir__, 'templates', template_name))
        end
      end
    end
  end
end
