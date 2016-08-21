class ConversationBot
  NOW_TIME = /now|ahora/i.freeze

  CALL_FOR_HELP = /\Ahelp|ayuda\z/i.freeze

  NUMBER_STRINGS = {
      0 => [/0/, /zero/, /none/, /cero/, /nada/],
      1 => [/1/, /one/, /uno/],
      2 => [/2/, /two/, /dos/],
      3 => [/3/, /three/, /tres/],
      4 => [/4/, /four/, /cuatro/]
  }.freeze

  DONT_KNOW_FRAGMENTS = [/don'*t know/i, /unsure/i, /dunno/i, /skip/i, /omitir/i, /seguro/i, /no se/i, /no sé/i].freeze

  # accepts a conversation at a certain state and a new message that has arrived
  def initialize convo, message
    @conversation = convo
    @bot_counter = convo.bot_counter
    @username = @conversation.username.split(' ').first
    @message = message
    @body = @message.body.strip
    @locale = convo.user.language
  end

  # returns an appropriate response to the new message and updates the conversation
  # we have one method for each conversation lifecycle and it returns the retries
  # count for the conversation. Updating this on the conversation will update the
  # conversation lifecyle.
  def response
    if @body =~ CALL_FOR_HELP
      stalled
    else
      current_lifecycle = @conversation.lifecycle
      new_counter = send(current_lifecycle.to_sym)
      # force update if counter doesn't change
      @conversation.update_attributes(bot_counter: new_counter, updated_at: Time.now)
      @response
    end
  end

  private
  def created
    # Lifecycle: created
    # Prompt for: language first time in
    # Look for: language
    case @bot_counter
      when 0
        @response = 'Hi, thanks for contacting us for a ride! This is an automated system. Reply "1" for English, Responder "2" para el español.'
        return 1
      when 1..2
        lang = if @body =~ /1/ || @body.downcase =~ /eng/
                 :en
               elsif @body =~ /2/ || @body.downcase =~ /esp/
                 :es
               end
        if lang
          @conversation.user.update_attribute(:language, lang)
          @response = I18n.t(:what_is_your_name, locale: lang)
          return 0
        end
        @response = 'Sorry I did not understand. Reply help/ayuda to reach a person. Please reply with "1" for English. Responder "2" para el español.'
        return @bot_counter + 1
      else
        @response = 'Someone will contact you soon - Alguien se pondrá en contacto en breve'
        return @bot_counter
    end
  end

  def have_language
    # Lifecycle: have language
    # Look for: name
    case @bot_counter
      when 0..1
        if @body.blank?
          @response = I18n.t(:empty_need_name, locale: @locale)
          return @bot_counter + 1
        end
        @conversation.user.update_attribute :name, @body
        @response = I18n.t(:what_is_pickup_location, locale: @locale, name: @body.split(' ').first)
        return 0
      else
        stalled
    end
  end

  def have_prior_ride
    # Lifecycle: have language and name and there was a prior completed ride
    # Prompt for: go back to <address>
    # Look for: yes/no
    recent_ride = @conversation.user.recent_complete_ride
    from_address = recent_ride.to_address
    to_address = recent_ride.from_address
    case @bot_counter
      when 0
        @response = I18n.t(:are_you_going_from_to, locale: @locale, from: from_address, to: to_address)
        return 1
      when 1
        if positive_answer
          @conversation.invert_ride_addresses(recent_ride)
          @response = I18n.t(:when_do_you_want_pickup, locale: @locale)
          return 0
        end
        # if not positive answer, assume a no, tell conversation to ignore prior ride and ask for origin
        @conversation.update_attribute :ignore_prior_ride, true
        @response = I18n.t(:what_is_pickup_location, locale: @locale, name: @username)
        return 0
      else
        stalled
    end
  end

  def have_name
    # Lifecycle: have language and name
    # Look for: pickup location
    # if this is a newly created sms conversation for an existing user, ask for origin
    if @conversation.status == 'sms_created'
      @response = I18n.t(:what_is_pickup_location, locale: @locale, name: @username)
      return 0
    end
    handle_location(:from)
  end

  def have_origin
    # Lifecycle: have language and name and we saved a single matching address
    # Look for: confirmation of the address
    if positive_answer
      @conversation.update_attribute(:from_confirmed, true)
      @response = I18n.t(:what_is_destination_location, locale: @locale)
      return 0
    end
    # go back to prompt for pickup location
    @response = I18n.t(:what_is_pickup_location, locale: @locale, name: @username)
    @conversation.update_attributes(from_latitude: nil, from_longitude: nil, from_confirmed: false)
    return 0
  end

  def have_confirmed_origin
    # Lifecycle: have language, name, and origin was confirmed
    # Look for: destination address
    handle_location(:to)
  end

  def have_destination
    # Lifecycle: have language and name and we saved a single matching address for destination
    # Look for: confirmation of the address
    if positive_answer
      @conversation.update_attribute(:to_confirmed, true)
      @response = I18n.t(:when_do_you_want_pickup, locale: @locale)
      return 0
    end
    # go back to prompt for destination location
    @response = I18n.t(:what_is_destination_location, locale: @locale)
    @conversation.update_attributes(to_latitude: nil, to_longitude: nil, to_confirmed: false)
    0
  end

  def have_confirmed_destination
    # Lifecycle: have language and name and confirmed origin and destination
    # Look for: time of day
    case @bot_counter
      when 0..1
        offset = Time.now.utc_offset - @conversation.ride_zone.utc_offset
        # try to bound time to avoid am/pm problems
        result = if @body =~ NOW_TIME
                   Time.at(Time.now.to_i + offset)
                 else
                   Time.parse(@body) rescue nil
                 end
        if result
          # this is now a local time where server is located, we need to get to UTC
          # then adjust for ride zone time zone. When displaying back, use the local parsed time
          voter_time = Time.at(result.to_i + offset)
          if voter_time.to_i >= Time.now.to_i - 10.minutes
            @conversation.update_attribute(:pickup_time, voter_time)
            @response = I18n.t(:confirm_the_time, locale: @locale, time: result.strftime('%l:%M %P'))
            return 0
          end
        end
        @response = I18n.t(:invalid_time, locale: @locale)
        return @bot_counter + 1
      else
        stalled
    end
  end

  def have_time
    # Lifecycle: have language and name and confirmed origin and destination and initial time entry
    # Look for: confirmation of time
    if positive_answer
      @conversation.update_attribute(:time_confirmed, true)
      @response = I18n.t(:how_many_additional, locale: @locale)
      return 0
    end
    # Go back to asking for time
    @conversation.update_attribute(:pickup_time, nil)
    @response = I18n.t(:when_do_you_want_pickup, locale: @locale)
    return 0
  end

  def have_confirmed_time
    # Lifecycle: have language and name and confirmed origin and destination and confirmed time
    # Look for: additional passengers
    case @bot_counter
      when 0..1
        num = numeric_answer
        if num
          @conversation.update_attribute(:additional_passengers, num)
          @response = I18n.t(:any_special_requests, locale: @locale)
          return 0
        end
        @response = I18n.t(:invalid_passengers, locale: @locale)
        return @bot_counter + 1
      else
        stalled
    end
  end

  def have_passengers
    # Lifecycle: have language and name and confirmed origin and destination and confirmed time and passengers
    # Look for: special requests
    # And fini!
    @conversation.update_attributes(special_requests: @body, status: :ride_created)
    Ride.create_from_conversation(@conversation)
    @response = I18n.t(:thanks_wait_for_driver, locale: @locale)
    0
  end

  def info_complete
    # Whoops, we got something after all info complete, this needs attention
    stalled
    0
  end

  # Expects to be receiving an address in the message body
  def handle_location(from_or_to)
    max_counter = (from_or_to == :from) ? 2 : 1
    case @bot_counter
      when 0..max_counter
        if @body.blank?
          @response = I18n.t(:no_address_match, locale: @locale)
          return @bot_counter + 1
        elsif dont_know_answer
          return give_up_on_location(from_or_to)
        end

        results = GooglePlaces.search(@body + ' ' + @conversation.ride_zone.state)
        if results.count == 1
          result = results.first
          formatted = result['formatted_address'].sub(/, USA|, United States/, '')
          st_zip_matcher = formatted.match(/, ([A-Z]{2}) ([0-9-]*)\z/)
          city_matcher = formatted.match(/, (.*), ([A-Z]{2}) ([0-9-]*)\z/)
          # keep city in the confirmation message
          confirm = if st_zip_matcher
                      formatted.sub(/#{st_zip_matcher}/, '')
                    else
                      formatted
                    end
          # remove city from address line if we found it
          addr = if city_matcher
                   formatted.sub(/#{city_matcher}/, '')
                 elsif st_zip_matcher
                   formatted.sub(/#{st_zip_matcher}/, '')
                 else
                   formatted
                 end
          @conversation.send("#{from_or_to}_address=".to_sym, addr)
          @conversation.send("#{from_or_to}_city=".to_sym, city_matcher[1]) if city_matcher
          @conversation.send("#{from_or_to}_latitude=".to_sym, result['geometry']['location']['lat'])
          @conversation.send("#{from_or_to}_longitude=".to_sym, result['geometry']['location']['lng'])
          name = result['name']
          confirm = "#{name} - #{confirm}" unless name.blank?
          @response = I18n.t(:confirm_address, locale: @locale, address: confirm)
          return 0
        end
        if results.count > 1
          @response = I18n.t(:too_many_addresses, locale: @locale)
        else
          @response = I18n.t(:no_address_match, locale: @locale)
        end
        return @bot_counter + 1
      else
        give_up_on_location(from_or_to)
    end
  end

  def give_up_on_location(from_or_to)
    if from_or_to == :to
      # not knowing destination is OK
      @conversation.set_unknown_destination
      @response = I18n.t(:when_do_you_want_pickup, locale: @locale)
      0
    else
      stalled
    end
  end

  def stalled
    @conversation.update_attribute(:status, :help_needed)
    @response = I18n.t(:bot_stalled, locale: @locale || :en)
    @bot_counter
  end

  def positive_answer
    @body.downcase =~ /y|right|correct|good|sure|cierto|bien|si|sí/
  end

  # we have some expressions for don't know, unsure but to avoid matching an
  # address accidentally, make sure there are no digits in the answer too
  def dont_know_answer
    (@body =~ /[0-9]/).nil? && DONT_KNOW_FRAGMENTS.any? { |f| @body =~ f }
  end

  def numeric_answer
    input = @body.downcase
    NUMBER_STRINGS.each do |num, list|
      return num if list.any? {|regex| input =~ regex}
    end
    nil
  end
end