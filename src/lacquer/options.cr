require "option_parser"
require "system"

module Lacquer
	class Options

		OPTIONS = Options.new

		property  process   = System.cpu_count,
							directory = "./public",
							prefix    = ""

		def initialize
			OptionParser.parse! do |parser|
				parser.banner = "Usage: salute [arguments]"
				parser.on("-p", "--process=PROCESS",     "Number of process to lunch") { |value| process   = value }
				parser.on("-d", "--directory=DIRECTORY", "Directory to serve")         { |value| directory = value }
				parser.on("-r", "--prefix=PREFIX",       "Prefix on HTTP request URI") { |value| prefix    = value }
				parser.on("-h", "--help",                "Show this help") { puts parser }
			end
		end

		def self.options
			OPTIONS
		end
	end
end
