module Api
  module V1
    class PostsController < Api::BaseController

      before_filter :ensure_params_post_exist, only: [:create]
      before_filter :validate_authentication_token
      before_filter :validate_post_object, except: [:create, :editors_picks, :popular_quotes]

      def create
        post = current_user.posts.build(params[:post])
        
        if post.save
          render json: post.to_builder.target!, status: 200
          return
        else
          render json: post.to_builder.target!, status: 200
        end
      end

      def show
        json = Jbuilder.encode do |json|
          json.data do |data|
            data.post do |post|
              post.caption instance_post.caption
              post.editors_pick instance_post.editors_pick
              post.post_id instance_post.id
              post.likes_count instance_post.likes_count
              post.quote instance_post.quote
              post.quote_image instance_post.quote_image
              post.user instance_post.user, :id, :full_name, :profile_picture
            end
          end
          json.success true
        end

        render json: json, status: 200
      end

      def likes
        json =  case request.method
                when "GET" then process_get
                when "POST" then process_post
                when "DELETE" then process_delete
                end

        render json: json, status: 200
      end

      def editors_picks
        options = {
          start_date: params[:start_date],
          end_date: params[:end_date],
          min_id: params[:min_id],
          max_id: params[:max_id],
          count: params[:count]
        }
        options.reject!{ |k,v| v.blank? }

        @posts = Post.editors_picked(options)

        json = posts_collection

        render json: json, status: 200
      end

      def popular
        options = {
          start_date: params[:start_date],
          end_date: params[:end_date],
          min_id: params[:min_id],
          max_id: params[:max_id],
          count: params[:count]
        }
        options.reject!{ |k,v| v.blank? }

        @posts = Post.popular(options)

        json = posts_collection

        render json: json, status: 200
      end

      protected

        def posts_collection
          Jbuilder.encode do |json|
            json.data do |data|
              data.posts do |posts|
                posts.array! @posts do |post|
                  posts.caption post.caption
                  posts.editors_pick post.editors_pick
                  posts.likes_count post.likes_count
                  posts.quote post.quote
                  posts.post_id post.id
                  posts.set! :user do
                    posts.set! :user_id, post.user_id 
                    posts.(post.user, :full_name, :profile_picture)
                  end
                end
              end
            end
            json.success true
          end
        end

        def process_get
          json = Jbuilder.encode do |json|
            json.data do |data|
              data.users(instance_post.users_liked.order('likes.created_at DESC'), :id, :full_name, :profile_picture)
            end
            json.success true
          end

          return json
        end

        def process_post
          instance_post.likes.find_or_create_by_user_id(current_user.id)
          {success: true, data: nil}.to_json
        end

        def process_delete
          like = instance_post.likes.find_by_user_id(current_user.id)
          like.destroy if like.present?
          {success: true, data: nil}.to_json
        end

        def instance_post
          @instance_post ||= Post.find(params[:id])
        end

        def ensure_params_id_exist
          return unless params[:id].blank?
          render json: { success: false, message: "Missing post_id parameter" }, status: 200
        end

        def check_existence_of_post
          return if Post.exists?(id: params[:id])
          render json: { success: false, message: "Post not found" }, status: 200
        end

        def validate_post_object
          ensure_params_id_exist || check_existence_of_post
        end

        def ensure_params_post_exist
          return unless params[:post].blank?
          render json: { success: false, message: "Missing post parameter" }, status: 200
        end
    end
  end
end