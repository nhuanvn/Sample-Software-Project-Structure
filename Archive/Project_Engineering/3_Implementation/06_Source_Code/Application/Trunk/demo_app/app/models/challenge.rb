class Challenge < ActiveRecord::Base

  #Constants
  PALEO = "Paleo"

  #Callbacks
  after_update :after_update_challenge
  before_destroy :send_email_before_destroy

  #Setup accessible attributes
  attr_accessible :name, :start_date, :duration, :status, :challenge_type, :creator_id, :end_date

  #Relationship
  belongs_to :creator, :class_name => "User", :foreign_key => "creator_id"

  has_many :biometrics, :dependent => :destroy

  has_many :attend_challenges, :dependent => :destroy
  has_many :users, :through => :attend_challenges

  #Named scopes
  #Find all challenge created by user
  scope :by_user, lambda { |creator_id|
    {:conditions => {:creator_id => creator_id}}
  }

  #Find upcoming challenges, exclude some ids
  scope :upcoming, lambda { |ids| where {(start_date.gt Date.current) & (id.not_in ids)} }

  #Find all upcoming challenge
  scope :upcoming_guest, where {start_date.gt Date.current}

  ##
  #Insert a challenge
  #Parameters::
  # *(params) *params*: list of param
  #Return::
  #
  #*Author*:: LamPV
  def self.insert(creator_id, params)
    name = params[:challenge][:name]
    start_date = Date.strptime(params[:challenge][:start_date],'%Y-%m-%d')
    duration = params[:challenge][:duration]
    status = params[:status]
    challenge_type = PALEO
    creator_id = creator_id
    end_date = start_date + duration.to_i.days

    self.create({
      :name => name,
      :start_date => start_date,
      :duration => duration,
      :challenge_type => challenge_type,
      :creator_id => creator_id,
      :status => true,
      :end_date => end_date
      })
  end

  ##
  #Check if the challenge is active or not
  #Return::
  # * (Boolean) challenge is active or not
  #*Author*:: NamTV
  def is_active?
    return true if status && Date.current < start_date
    return false
  end

  ##
  #Check if the challenge is running or not
  #Return::
  # * (Boolean) challenge is running or not
  #*Author*:: NamTV
  def is_running?
    return true if status && Date.current >= start_date && (Date.current <= (start_date + duration.days))
    return false
  end

  ##
  #Get list of challenges which created by a user
  #Parameters::
  # *(Integer) *user_id*: id of creator
  # *(Integer) *page*: current page
  # *(Integer) *per_page*: challenges per page
  #*Author*:: LamPV
  def self.get_list_of_challenge(user_id, page, per_page)
    challenges = by_user(user_id).order("start_date DESC").paginate(:page => page, :per_page => per_page)
  end

  ##
  #Get list of challenges
  #Parameters::
  # *(Integer) *page*: current page
  # *(Integer) *per_page*: challenges per page
  #*Author*:: LamPV
  def self.get_all_challenges(page, per_page)
    challenges = Challenge.order("start_date DESC").paginate(:page => page, :per_page => per_page)
  end

  ##
  #Get list of challenges which user attended
  #Parameters::
  # *(User) *user*: targeted user
  # *(Integer) *page*: current page
  # *(Integer) *per_page*: challenges per page
  #*Author*:: LamPV
  def self.get_list_of_attend_challenge(user, page, per_page)
    challenges = user.joined_challenges.where(:status => true, "attend_challenges.token" => nil).order("end_date DESC").paginate(:page => page, :per_page => per_page)
  end

  ##
  #Get list of upcoming challenges for a user
  #Parameters::
  # *(User) *user*: targeted user
  # *(Integer) *page*: current page
  # *(Integer) *per_page*: challenges per page
  #*Author*:: LamPV
  def self.get_all_upcoming_challenge(user, page, per_page)
    if user
      challenges = upcoming(user.joined_challenge_ids).where(:status => true).order("start_date DESC").paginate(:page => page, :per_page => per_page)
    else
      challenges = upcoming_guest.where(:status => true).order("start_date DESC").paginate(:page => page, :per_page => per_page)
    end
  end

  ##
  #Auto cancel challenges that do not have contestant, this method will be call automatically by scheduler each day
  #*Author*:: NamTV
  def self.auto_cancel_challenges

    #Get all challenges that is running
    all_challenges = Challenge.where{(start_date.lteq Date.current) & (status.eq true) & ((start_date + duration).gteq Date.current)}

    all_challenges.each do |c|
      contestants_count = c.attend_challenges.count

      #If challenge has no contestant or has 1 contestant but this is the creator of this challenge
      if(contestants_count == 0 || (contestants_count == 1 && c.attend_challenges.first.user_id == c.creator_id))
        c.status = false
        c.save
      end
    end
  end

  protected

    ##
    #Callback after update challenge
    #*Author*:: NamTV
    def after_update_challenge
      send_email_after_canceled_reactive
      send_email_after_change_start_date
    end

    ##
    #Send email to notify users after challenge is canceled or reactived
    #*Author*:: NamTV
    def send_email_after_canceled_reactive

      #Do nothing if status not change
      return if(!self.status_changed?)

      contestants = self.users

      #For active challenge
      if(self.status)

        #Send email to creator
        UserMailer.challenge_reactivated_creator(self.creator, self).deliver

        #Send email to contestants
        contestants.each do |c|
          UserMailer.challenge_reactivated_contestant(c, self).deliver
        end

      #For canceled challenge
      else

        #Send email to creator
        UserMailer.challenge_canceled_creator(self.creator, self).deliver

        #Send email to contestants
        contestants.each do |c|
          UserMailer.challenge_canceled_contestant(c, self).deliver
        end
      end
    end

    ##
    #Send email to notify users after challenge is deleted
    #*Author*:: NamTV
    def send_email_before_destroy

      #Do nothing if challenge has been closed
      return if(self.start_date + self.duration < Date.current)

      contestants = self.users

      #Send email to creator
      UserMailer.challenge_deleted_creator(self.creator, self).deliver

      #Send email to contestants
      contestants.each do |c|
        UserMailer.challenge_deleted_contestant(c, self).deliver
      end

    end

    ##
    #Send email to notify users after challenge start date has been changed
    #*Author*:: NamTV
    def send_email_after_change_start_date

      #Do nothing if start_date not change
      return if(!self.start_date_changed?)

      contestants = self.users

      #Send email to creator
      UserMailer.start_date_change_creator(self.creator, self).deliver

      #Send email to contestants
      contestants.each do |c|
        UserMailer.start_date_change_contestant(c, self).deliver
      end

    end
end