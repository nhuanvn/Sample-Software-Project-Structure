class ChallengesController < ApplicationController
  before_filter :authenticate_user!, :except => [:upcoming_challenge, :edit]
  ##
  #Handle index request show list of challenge
  #Return::
  #*Author*:: LamPV
  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    if current_user.is_admin?
      @challenges = Challenge.get_all_challenges(page, per_page)
    elsif current_user.is_creator && !params[:creator]
      @challenges = Challenge.get_list_of_challenge(current_user.id, page, per_page)
    else
      @challenges = Challenge.get_list_of_attend_challenge(current_user, page, per_page)
    end
  end

  ##
  #Handle create request create new challenge
  #Return::
  #*Author*:: LamPV
  #
  def create
    if current_user.is_creator
      creator_id = current_user.id
      challenge = Challenge.insert(creator_id, params)

      if(params[:is_joined])

        current_user.activate_join_challenge(current_user.request_join_challenge(challenge, true))
      end
      redirect_to challenges_path
    end
  end
  ##
  #Handle new request new challenge
  #Return::
  #*Author*:: LamPV
  #
  def new
    render :text => "<br /><br /><br /><br /><p><h2>Access Denied</h2>You don't have permission to access this page.</p><br /><br /><br /><br />", :layout => true if !current_user.is_creator
    @challenge = Challenge.new
  end

  ##
  #Handle edit challenge
  #Return::
  #*Author*:: LamPV
  def edit
    @challenge = Challenge.find(params[:id])

    #Determine that current user can join this challenge or not
    @has_join = !current_user.nil? && !current_user.is_admin? && (!current_user.joined_challenge_ids.include? @challenge.id) && @challenge.start_date > Date.current
  end

  ##
  #Handle update request update challlenge
  #Return::
  #*Author*:: LamPV
  def update
    @challenge = Challenge.find(params[:id])

    new_start_date = Date.strptime(params[:challenge][:start_date],'%Y-%m-%d')
    params[:challenge][:start_date] = new_start_date
    params[:end_date] = params[:challenge][:start_date] + params[:challenge][:duration].to_i.days

    if @challenge.update_attributes(params[:challenge])
      flash[:update] = true
      redirect_to edit_challenge_path(@challenge)
    else
      render "edit"
    end
  end

  ##
  #Get upcoming chanllenges
  #Return::
  #*Author*:: LamPV
  #
  def upcoming_challenge
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @challenges = Challenge.get_all_upcoming_challenge(current_user, page, per_page)
  end

  ##
  #Cancel a challenge
  #Return::
  #*Author*:: LamPV
  #
  def cancel
    @challenge = Challenge.find(params[:id])

    @challenge.status = false
    @challenge.save
    render :json => {:success => true}
  end

  ##
  #Activate a challenge
  #Return::
  #*Author*:: LamPV
  #
  def reactive
    @challlenge = Challenge.find(params[:id])

    @challlenge.status = true
    @challlenge.save
    render :json => {:success => true}
  end

  ##
  #Post event to facebook
  #Return::
  #*Author*:: ChienTX
  #
  def post_event_to_facebook
    begin
      access_token = params[:access_token]
      challenge = Challenge.find(params[:id])
      event_params = {
        :name => challenge.name,
        :description => "Welcome everybody to join our challenge. Register now to improve yourself with BodyAsRx: " + request.protocol + request.host_with_port + upcoming_challenge_challenges_path,
        :start_time => challenge.start_date,
        :end_time => challenge.end_date,
        :privacy => 'OPEN'
      }

      graph = Koala::Facebook::API.new(access_token)
      graph.put_object('me', 'events', event_params)
      render :json => {:status => 'ok', :challenge => challenge}
    rescue
      render :json => {:status => 'nok'}
    end
  end

  ##
  #Handle destroy request destroy a challenge
  #Return::
  #*Author*:: LamPV
  #
  def destroy
    @challenge = Challenge.find(params[:id])
    @challenge.destroy
    render :json => {:success => true}
  end
end
