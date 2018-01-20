require "socket"
require "http"
require "http/client"
require "./lacquer/*"

module Lacquer

	# Cache
	@@cache = Hash(String, NamedTuple(content: Bytes, type: String, size: UInt64)).new

	# Handle each request
	def self.handle_client(client) : Nil

		# return if no socket
		return unless client

		# async
		client.sync = false

		# To bench
		ts      = Time.now
		# Initial requested path
		path    = ""
		# Read request from socket
		request = HTTP::Request.from_io client

		# If request is well formed
		if request.is_a?(HTTP::Request)

			# Get request path
			path = File.expand_path(request.path, Options.options.directory)

			# Create response
			resp = HTTP::Server::Response.new client

			# Set server header
			resp.headers["Server"] = "lacquer/#{ VERSION }"

			# If content is in cache
			if @@cache.has_key?(path)

				# get data from cache
				object = @@cache[path]

				# Set common headers
				resp.headers["Date"]           = Time.utc_now.to_s("%a, %d %b %Y %T GMT")
				resp.headers["Content-Type"]   = object[:type]
				resp.headers["Content-Length"] = object[:size].to_s

				# Write object to socket (response)
				resp.write object[:content]
			else
				# No object found in cache
				resp.respond_with_error("Not Found", 404)
			end

			# Always (200 and 404) close
			resp.output.close
			client.flush
			client.close unless client.closed?
			# Maybe there are a better way to do this
			request.body.try &.close
		else

			# Bad request
			resp = HTTP::Server::Response.new client
			resp.respond_with_error("Bad Request", 400)
			resp.close

			# Log it
			puts "#{ Time.now } #{ client.fd } - [#{ path }] #{ resp.status_code } - #{ "%.2f" % (Time.now - ts).total_milliseconds }ms"
		end

	rescue ex
		puts "Request error: #{ ex.message }"
	end

	# Mini-mime-type ;)
	def self.mime_type(extension) : String
		case extension
		when ".text", ".txt"
			"text/plain"
		when ".html", ".htm"
			"text/html"
		when ".json"
			"application/json"
		when ".xml"
			"application/xml"
		when ".png"
			"image/png"
		when ".jpeg", ".jpg"
			"image/jpeg"
		when ".gif"
			"image/gif"
		else
			"application/octet-stream"
		end
	end

	# Explore objects to import to cache
	def self.read_dir(dir) : Nil

		puts "Exploring: #{ dir }"

		# Explore directory "recursivedly"
		Dir.glob("#{ dir }/*") do |item|
			# If item is a directory, then explore again
			if File.directory?(item)
				read_dir(item)
			# Else, when it's a file then import to cache
			elsif File.file?(item)
				# Read item content
				File.open(item, "rb") do |fp|
					# Compose cache key
					key     = item[Options.options.directory.size, item.size - Options.options.directory.size]
					# Content-Length header
					content = Bytes.new(fp.size)
					# Content-Type header
					type    = self.mime_type File.extname(item)
					# Read it
					fp.read content
					# Add cache
					@@cache[key] = { content: content, type: type, size: fp.size }
					# Log it
					puts "Reading: #{ item } as #{ key } (#{ type } / #{ fp.size } blocks)"
				end
			end
		end
	rescue ex
		puts "ReadDir error: #{ ex.message }"
	end

	# Ensure if dir exists
	unless Dir.exists?(Options.options.directory)
		puts "Can't access to '#{ Options.options.directory }' directory."
		exit 1
	end

	# Populate cache
	puts "Exploring for files..."
	read_dir(Options.options.directory)

	# Raising up sockets
	server = TCPServer.new("localhost", 1234, reuse_port: true)
	# Listen each request
	while client = server.accept?
		spawn self.handle_client(client)
	end
end
