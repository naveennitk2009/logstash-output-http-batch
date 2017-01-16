# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "logstash/json"
require "uri"
require "logstash/plugin_mixins/http_client"

class LogStash::Outputs::HttpBatch < LogStash::Outputs::Base
  include LogStash::PluginMixins::HttpClient

  VALID_METHODS = ["put", "post", "patch", "delete", "get", "head"]

  # This output lets you send events to a
  # generic HTTP(S) endpoint
  #
  # This output will execute up to 'pool_max' requests in parallel for performance.
  # Consider this when tuning this plugin for performance.
  #
  # Additionally, note that when parallel execution is used strict ordering of events is not
  # guaranteed!
  #
  # Beware, this gem does not yet support codecs. Please use the 'format' option for now.

  config_name "httpbatch"

  # URL to use
  config :url, :validate => :string, :required => :true

  # The HTTP Verb. One of "put", "post", "patch", "delete", "get", "head"
  config :http_method, :validate => VALID_METHODS, :required => :true

  # Custom headers to use
  # format is `headers => ["X-My-Header", "%{host}"]`
  config :headers, :validate => :hash

  # Content type
  #
  # If not specified, this defaults to the following:
  #
  # * if format is "json", "application/json"
  config :content_type, :validate => :string

  # Set the format of the http body.
  # For now it just supports json
  config :format, :validate => ["json"], :default => "json"

  def register
    @http_method = @http_method.to_sym

    # We count outstanding requests with this queue
    # This queue tracks the requests to create backpressure
    # When this queue is empty no new requests may be sent,
    # tokens must be added back by the client on success
    @request_tokens = SizedQueue.new(@pool_max)
    @pool_max.times {|t| @request_tokens << true }

    @requests = Array.new

    if @content_type.nil?
      case @format
        when "json" ; @content_type = "application/json"
      end
    end
  end # def register

  def multi_receive(events)
    #Sending all the events receieved from input as a batch. Thus batch size is controlled by pipeline.batch.size or pipeline.batch.delay in logstash.yml. 
    #This makes it a lot performant for logstash as the batching will be increased or decresed as per how fast logstash is able to send the requests for processing.
    receive(events, :parallel) 
    client.execute!
  end

  # Once we no longer need to support Logstash < 2.2 (pre-ng-pipeline)
  # We don't need to handle :background style requests
  #
  # We use :background style requests for Logstash < 2.2 because before the microbatching
  # pipeline performance is greatly improved by having some degree of async behavior.
  #
  # In Logstash 2.2 and after things are much simpler, we just run each batch in parallel
  # This will make performance much easier to reason about, and more importantly let us guarantee
  # that if `multi_receive` returns all items have been sent.
  def receive(events, async_type=:background)
    body = event_body(events)

    # Block waiting for a token
    token = @request_tokens.pop if async_type == :background

    # Send the request
    url = @url
    headers = event_headers()

    # Create an async request
    request = client.send(async_type).send(@http_method, @url, :body => body, :headers => headers)

    request.on_complete do
      # Make sure we return the token to the pool
      @request_tokens << token  if async_type == :background
    end

    request.on_success do |response|
      if response.code < 200 || response.code > 299
        log_failure(
          "Encountered non-200 HTTP code #{response.code}",
          :response_code => response.code,
          :url => url)
      end
    end

    request.on_failure do |exception|
      log_failure("Could not fetch URL",
                  :url => url,
                  :method => @http_method,
                  :body => body,
                  :headers => headers,
                  :message => exception.message,
                  :class => exception.class.name,
                  :backtrace => exception.backtrace
      )
    end

    request.call if async_type == :background
  end

  def close
    client.close
  end

  private

  # This is split into a separate method mostly to help testing
  def log_failure(message, opts)
    @logger.error("[HTTP Output Failure] #{message}", opts)
  end

  # Manticore doesn't provide a way to attach handlers to background or async requests well
  # It wants you to use futures. The #async method kinda works but expects single thread batches
  # and background only returns futures.
  # Proposed fix to manticore here: https://github.com/cheald/manticore/issues/32
  def request_async_background(request)
    @method ||= client.executor.java_method(:submit, [java.util.concurrent.Callable.java_class])
    @method.call(request)
  end

  # Format the HTTP body
  def event_body(events)
    # TODO: Create an HTTP post data codec, use that here
    if @format == "json"
      LogStash::Json.dump(events)
    else 
      @logger.error("Only supported format is Json")
    end
  end

  def event_headers()
    headers = custom_headers() || {}
    headers["Content-Type"] = @content_type
    headers
  end

  def custom_headers()
    return nil unless @headers

    @headers.reduce({}) do |acc,kv|
      k,v = kv
      acc[k] = v
      acc
    end
  end
end