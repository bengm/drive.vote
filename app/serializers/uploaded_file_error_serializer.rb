module UploadedFileErrorSerializer

  def self.serialize(rides)
    return if rides.nil?

    json = {}
    total_hash = Hash.new

    rides.each_with_index do |ride, index|
      csv_row = index + 2 # make it easier for end user to find problem
      row_hash = ride.errors.full_messages.each do |msg|
        {msg: msg}
      end.flatten
      total_hash[csv_row] = row_hash
    end
    json[:errors] = total_hash
    json
  end

end