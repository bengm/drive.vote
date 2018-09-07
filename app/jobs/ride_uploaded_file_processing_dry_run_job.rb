class RideUploadedFileProcessingDryRunJob < ApplicationJob
  queue_as :default

  def perform(ride_uploaded_file_id)
    @ride_uploaded_file = RideUploadedFile.find ride_uploaded_file_id

    @ride_uploaded_file.processed = true

    @ride_uploaded_file.save!
  end
end
