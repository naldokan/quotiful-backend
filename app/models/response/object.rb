require "em-synchrony"
require "em-synchrony/fiber_iterator"
require "thread"

module Response
  class Object
    include Rails.application.routes.url_helpers

    attr_accessor :class_name, :object, :options

    # options:
    # alt_key - alternative hash key for json
    # current_user_id - user ID of authenticated user
    # errors - array of actual errors
    # success - actual response status
    def initialize(class_name = '', object = {}, options = {})
      @class_name = class_name
      @object = object
      @options = options
    end

    def inspect
      object
    end

    def success
      @success ||= options[:success] || !errors.present?
    end

    def errors
      full_messages = (object.present? and data.present?) ? object.errors.full_messages : []
      @errors ||= options[:errors] || full_messages
    end

    def data
      return {} unless object.is_a?(class_name.classify.constantize)
      
      key = options[:alt_key].present? ? options[:alt_key].to_sym : class_name.to_sym
      
      {
        key => send("#{class_name}_hash")
      }
    end

    def to_hash
      EM.synchrony do
        @hash = {}
        @hash[:data] = data
        @hash[:data][:params] = options[:params] || {}
        @hash[:errors] = errors if errors.present?
        @hash[:success] = success
        @hash[:api_version] = options[:api_version] || nil
        
        EM.stop
      end

      return @hash
    end

    def to_json
      @json = to_hash.to_json

      return @json
    end

    def current_user
      @current_user ||= User.find(options[:current_user_id]) if options[:current_user_id].present?
    end

    def relative_user
      @relative_user ||= User.find(options[:relative_user_id]) if options[:relative_user_id].present?
    end

    def activity_hash(activity = object)
      {
        activity_id: negate_id(activity.id),
        body: activity.body,
        identifier: activity.custom_payloads.symbolize_keys[:identifier],
        timestamp: activity.created_at.to_i,
        details: activity.tagged_details(options)
      }
    end

    def author_hash(author = object)
      {
        id: negate_id(author.id),
        author_id: negate_id(author.id),
        name: author.name,
        first_name: author.first_name,
        last_name: author.last_name
      }
    end

    def comment_hash(comment = object)
      {
        id: negate_id(comment.id),
        comment_id: negate_id(comment.id),
        post_id: negate_id(comment.commentable_id),
        body: comment.body,
        description: comment.description,
        commented_at: comment.created_at.to_i,
        tagged_users: comment.tagged_users,
        user: user_hash(comment.user)
      }
    end

    def post_hash(post = object)
      {
        post_id: negate_id(post.id),
        quote: post.quote,
        quote_image_url: post.quote_image_url,
        author_name: post.author_name,
        caption: post.caption,
        description: post.description,
        editors_pick: post.editors_pick,
        likes_count: post.likes.count,
        posted_at: post.created_at.to_i,
        web_url: post_url(post.posted_at, host: DEFAULT_HOST),
        background_image_url: post.background_image_url,
        quote_attr: post.quote_attr,
        author_attr: post.author_attr,
        quotebox_attr: post.quotebox_attr,
        origin_id: post.origin_id,
        tagged_users: post.tagged_users,
        s_thumbnail_url: post.quote_image_url('56x56#'),
        m_thumbnail_url: post.quote_image_url('140x140#'),
        l_thumbnail_url: post.quote_image_url('290x290#'),
        flagged_count: post.flagged_count,
        user: user_hash(post.user)
      }.update(post_with_current_user_id(options[:current_user_id], post)).update(post_image_override(options[:override], post))
    end

    def post_lean_hash(post = object)
      {
          post_id: negate_id(post.id),
          quote_image_url: post.quote_image_url,
          m_thumbnail_url: post.quote_image_url('140x140#'),
          user_id: negate_id(post.user.id)
      }
    end

    def post_for_download_hash(post = object)
      {
          quote_image_url: post.quote_image_url
      }
    end

    def post_explore_lean_hash(post = object)
      {
          post_id: negate_id(post.id),
          quote_image_url: post.quote_image_url,
          m_thumbnail_url: post.quote_image_url('290x290#'),
          user_id: negate_id(post.user.id)
      }
    end

    def post_home_lean_hash(post = object)
      {
          post_id: negate_id(post.id),
          quote_image_url: post.quote_image_url,
          posted_at: post.created_at.to_i,
          likes_count: post.likes.count,
          caption: post.caption,
          web_url: post_url(post.posted_at, host: DEFAULT_HOST),
          full_name: post.user.full_name,
          profile_picture_url: post.user.profile_picture_url,
          user_id: negate_id(post.user.id)
      }.update(post_with_current_user_id(options[:current_user_id], post)).update(post_image_override(options[:override], post))
    end

    def preset_category_hash(preset_category = object)
      {
        id: negate_id(preset_category.id),
        category_id: negate_id(preset_category.id),
        name: preset_category.name,
        preset_images_count: preset_category.preset_images_count,
        preset_image_sample: preset_category.preset_image_sample,
        images: Response::Collection.new('preset_image', preset_category.preset_images).collective_hash
      }
    end

    def preset_category_lean_hash(preset_category = object)
      {
          id: negate_id(preset_category.id),
          category_id: negate_id(preset_category.id),
          name: preset_category.name,
          preset_images_count: preset_category.preset_images_count,
          preset_image_sample: preset_category.preset_image_sample
      }
    end

    def preset_image_hash(preset_image = object)
      {
        id: negate_id(preset_image.id),
        image_id: negate_id(preset_image.id),
        name: preset_image.name,
        image_name: preset_image.name,
        image_thumbnail_url: preset_image.preset_image_url('140x140#'),
        image_url: preset_image.preset_image_url,
        category_name: preset_image.preset_category_name
      }
    end

    def quote_hash(quote = object)
      {
        id: negate_id(quote.id),
        quote_id: negate_id(quote.id),
        author_full_name: quote.author_full_name.to_s,
        author_name: quote.author_name,
        author_first_name: quote.author_first_name.to_s,
        author_last_name: quote.author_last_name.to_s,
        body: quote.body
      }
    end

    def relationship_hash(relationship = object)
      {
        status: relationship.status,
        follower_id: negate_id(relationship.follower_id),
        following_id: negate_id(relationship.user_id),
        followed_at: relationship.created_at.to_i
      }
    end

    def tag_hash(tag = object)
      {
        id: negate_id(tag.id),
        tag_id: negate_id(tag.id),
        name: tag.name,
        posts_count: tag.posts.count
      }
    end

    def topic_hash(topic = object)
      {
        id: negate_id(topic.id),
        topic_id: negate_id(topic.id),
        name: topic.name
      }
    end

    def user_hash(user = object)
      {
        user_id: negate_id(user.id),
        full_name: user.full_name,
        profile_picture_url: user.profile_picture_url,
        s_thumbnail_url: user.profile_picture_url('56x56#'),
        m_thumbnail_url: user.profile_picture_url('140x140#'),
        favorite_quote: user.favorite_quote,
        author_name: user.author_name,
        website: user.website,
        follows_count: user.followed_by_self.active.count,
        followed_by_count: user.followed_by_users.active.count,
        posts_count: user.posts.count,
        collection_count: user.collections.count,
        birth_date: user.birth_date,
        gender: user.gender,
        suggested: user.suggested,
        active: user.active
      }.update(user_is_current_user(user)).update(user_is_not_current_user(user))
    end

    protected

      def negate_id(id)
        # options.symbolize_keys!
        # (id > 32_767 and options[:api_version].to_i < 3) ? (id - 65_536) : id
        return id
      end

      def post_image_override(override, post)
        return {} unless override.present?

        {
          quote_image_url: post.quote_image_url('290x290#')
        }
      end

      def post_with_current_user_id(current_user_id, post)
        return {} unless current_user_id.present?
         
        {
          user_liked: post.liked_by?(options[:current_user_id]),
          in_collection: post.in_collection_of?(options[:current_user_id])
        }
      end

      def user_is_current_user(user)
        return {
          notifications: user.notifications,
          email: user.email,
          authentication_token: user.authentication_token,
          badge_count: user.activities.unread.count,
          has_password: user.has_password?
        } if current_user.present? and user.id == current_user.id
        
        {}
      end

      def user_is_not_current_user(user)
        return {
          following_me: current_user.following_me?(user.id),
          following_me_date: current_user.following_date(user.id),
          am_follower: current_user.am_follower?(user.id),
          am_follower_date: current_user.follower_date(user.id),
        }.update(user_is_not_relative_user(user)) if current_user.present? and user.id != current_user.id
        
        {}
      end

      def user_is_not_relative_user(user)
        return {
          following_them: relative_user.following_me?(user.id),
          following_them_date: relative_user.following_date(user.id),
          they_follow: relative_user.am_follower?(user.id),
          they_follow_date: relative_user.follower_date(user.id),
        } if relative_user.present? and user.id != relative_user.id
        
        {}
      end
  end
end