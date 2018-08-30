require 'securerandom'

class RidesController < ApplicationController
  include RideParams, RideZoneParams
  before_action :require_session, only: [:edit, :update]
  before_action :set_ride, only: [:edit, :update]
  before_action :require_ride_zone
  around_action :set_time_zone

  def new
    @locale = params[:locale]
    @validation_pattern = "( CA| ca| DC| dc| FL| fl| HI| hi| IL| il| NV| nv| NY| ny| OH| oh| PA| pa| UT| ut| WI| wi)"
    @ride = Ride.new
  end

  def create
    if params[:locale].present?
      @locale = params[:locale]
    else
      @locale = :en
    end
    user_params = params.require(:ride).permit(:user_id, :phone_number, :email, :name, :password, :locale)
    user_params[:locale] = @locale
    @ride, ok = Ride.create_with_user(ride_params, user_params, @ride_zone)
    if ok 
      @user = @ride.voter
      @pickup_at = @ride.pickup_at
      render :success and return
    else
      flash.now[:notice] = "Problem creating the ride."
      render :new and return
    end
  end

  def edit
    @validation_pattern = "( CA| ca| DC| dc| FL| fl| HI| hi| IL| il| NV| nv| OH| oh| PA| pa| UT| ut| WI| wi)"
    I18n.locale = @ride.voter.locale
    @ride_zone = @ride.ride_zone
    @pickup_at = @ride.pickup_in_time_zone
  end

  def update
    I18n.locale = @ride.voter.locale
    if @ride.update(ride_params)
      render :success
      @ride.conversation.send_from_staff(thanks_msg, Rails.configuration.twilio_timeout)
      UserMailer.welcome_email_voter_ride(@ride.voter, @ride).deliver_later
    else
      render :edit
    end
  end

  private
  def thanks_msg
    I18n.t(:thanks_for_requesting, locale: (@ride.voter.locale.blank? ? 'en' : @ride.voter.locale), time: @ride.pickup_in_time_zone.strftime('%m/%d %l:%M %P'), email: @ride.ride_zone.email)
  end

  def require_session
    redirect_to '/users/sign_in' unless user_signed_in?
  end

  def require_ride_zone
    @ride_zone = @ride.ride_zone if @ride
    set_ride_zone(:ride_zone_id) unless @ride_zone
    render :need_area unless @ride_zone
  end

  def set_time_zone(&block)
    Time.use_zone(@ride_zone.time_zone, &block) if @ride_zone
  end
end
