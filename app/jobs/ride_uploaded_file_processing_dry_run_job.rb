class RideUploadedFileProcessingDryRunJob < ApplicationJob
  include UploadedFileErrorSerializer

  queue_as :default

  def perform(ride_uploaded_file_id)
    @ride_uploaded_file = RideUploadedFile.find ride_uploaded_file_id

    ####
    ## create some fake rides and do some validation
    ride = Ride.new
    ride.from_zip = "wat" * 20

    array = Array.new

    array.push ride

    array.each do |ride|
      ride.save
    end

    ####

    @ride_uploaded_file.dry_run_errors = UploadedFileErrorSerializer.serialize(array)

    @ride_uploaded_file.save!

    @ride_uploaded_file.dry_run_completed = true

    ActionCable.server.broadcast "ride_uploaded_file_status_#{@ride_uploaded_file.id}", {id: @ride_uploaded_file.id, dry_run: true}
  end
end
