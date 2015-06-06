require "em-synchrony"
require "em-synchrony/fiber_iterator"
require "thread"

module Response
  class Object
    include Rails.application.routes.url_helpers

    attr_accessor :class_name, :object, :options

    def initialize(class_name = '', object = nil, options = {})
      @class_name = class_name
      @object = object
      @options = options
    end

    def inspect
      object
    end

    def success
      @success ||= options[:success] || true
    end

    def to_hash
      EM.synchrony do
        @hash = {}
        @hash[:data] = {}
        @hash[:data][class_name.to_sym] = send("#{class_name}_hash") if class_name.present?
        @hash[:success] = success

        EM.stop
      end

      return @hash
    end

    def to_json
      @json = to_hash.to_json

      return @json
    end

    def post_hash(object = object)
      return {} unless object.is_a?(Post)

      hash = {
        post_id: object.id,
        quote: object.quote,
        quote_image_url: object.quote_image_url,
        author_name: object.author_name,
        caption: object.caption,
        description: object.description,
        editors_pick: object.editors_pick,
        likes_count: object.likes.count,
        posted_at: object.created_at.to_i,
        web_url: post_url(object.created_at.to_i, host: DEFAULT_HOST),
        background_image_url: object.background_image_url,
        quote_attr: object.quote_attr,
        author_attr: object.author_attr,
        quotebox_attr: object.quotebox_attr,
        origin_id: object.origin_id,
        tagged_users: object.tagged_users,
        s_thumbnail_url: object.quote_image_url('28x28#'),
        m_thumbnail_url: object.quote_image_url('70x70#'),
        user: user_hash(object.user)
      }

      if options[:current_user_id].present?
        hash.update({
          user_liked: object.liked_by?(options[:current_user_id]),
          in_collection: false
        })
      end

      return hash
    end

    def user_hash(object = object)
      return {} unless object.is_a?(User)

      {
        user_id: object.id,
        full_name: object.full_name,
        profile_picture_url: object.profile_picture_url
      }
    end


  end
end