class Admin::UsersController < AdminController
  def index
    respond_to do |format|
      format.html do
        page = params[:page]
        query = params[:q]
        # @users = User.page(params[:page]).per(15).order("full_name ASC, email ASC")
        
        @users = User.search do
          fulltext(query) do
            fields :full_name
          end

          paginate(page: page, per_page: 15)

          order_by(:full_name, :asc)
          order_by(:email, :asc)
        end.results

        @db_count = User.count
        @solr_count = User.search.results.total_entries
      end

      format.csv do
        @users = User.order(:full_name)
        send_data @users.to_csv
      end
    end
  end

  def featured
    @users = User.suggested.active.order('full_name ASC, email ASC').page(params[:page]).per(15)
    @count = User.suggested.active.count
  end

  def edit
    @user = User.find(params[:id])
  end

  def posts
    @user = User.find(params[:id])
    @posts = @user.posts.page(params[:page]).per(15).order("posts.created_at DESC")
  end

  def update
    @user = User.find(params[:id])
    
    if @user.update_attributes(params[:user])
      redirect_to :back, notice: "Successfully updated the user information."
    else
      messages = @users.errors.full_messages.dup
      messages << nil

      redirect_to :back, alert: messages.join('. ')
    end
  end

  def suggest
    @user = User.find(params[:id])
    @user.update_attribute(:suggested, params[:sg].eql?('true'))

    redirect_to :back, notice: "Successfully updated the suggested users list."
  end

  def spammers
    @users = User.spammers.page(params[:page]).per(15)
  end

  def followers
    @user = User.find(params[:id])
    @users = @user.followed_by_users.order('full_name ASC, created_at DESC').page(params[:page]).per(20)
  end

  def following
    @user = User.find(params[:id])
    @users = @user.followed_by_self.order('full_name ASC, created_at DESC').page(params[:page]).per(20)
  end

  def reactivate
    user = User.find(params[:id])
    user.reactivate!

    redirect_to :back, notice: "Successfully reactivated the user."
  end

  def destroy
    user = User.find(params[:id])
    user.deactivate!

    redirect_to :back, notice: "Successfully deactivated the user."
  end

  def search
    @users = User.where("LOWER(users.full_name) LIKE ?", [params[:q].downcase, '%'].join).limit(8).pluck(:full_name)

    render json: @users.to_json
  end
end
