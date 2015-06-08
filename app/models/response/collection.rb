require "em-synchrony"
require "em-synchrony/fiber_iterator"
require "thread"

module Response
  class Collection
    include Rails.application.routes.url_helpers

    attr_accessor :class_name, :collection, :options

    def initialize(class_name = '', collection = [], options = {})
      @class_name = class_name
      @collection = collection
      @options = options
    end

    def inspect
      class_name.classify.constantize.new
    end

    def success
      @success ||= options[:success] || true
    end

    def to_hash
      EM.synchrony do
        @hash = {}
        @hash[:data] = {}
        @hash[:data][class_name.pluralize.to_sym] = send("#{class_name.pluralize}_hash") if class_name.present?
        @hash[:data][:user] = Response::Object.new('user', instance_user, options).user_hash if instance_user.present?
        @hash[:data][:page] = options[:page] || 1
        @hash[:success] = success

        EM.stop
      end

      return @hash
    end

    def to_json
      @json = to_hash.to_json

      return @json
    end

    def instance_user
      @instance_user ||= User.find(options[:instance_user_id]) if options[:instance_user_id].present?
    end

    def activities_hash
      array = []

      collection.each do |activity|
        array << Response::Object.new('activity', activity, options).activity_hash
      end

      return array
    end

    def posts_hash
      array = []

      collection.each do |post|
        array << Response::Object.new('post', post, options).post_hash
      end

      return array
    end

    def users_hash
      array = []

      collection.each do |user|
        array << Response::Object.new('user', user, options.update(relative_user_id: user.id)).user_hash
      end

      return array
    end

  end
end