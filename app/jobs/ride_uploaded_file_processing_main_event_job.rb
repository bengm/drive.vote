class RideUploadedFileProcessingDryRunJob < ApplicationJob
  include UploadedFileErrorSerializer

  queue_as :default

  def perform(ride_uploaded_file_id)
    @ride_uploaded_file = RideUploadedFile.find ride_uploaded_file_id

    @ride_uploaded_file.processed = true

    @ride_uploaded_file.save!

    ActionCable.server.broadcast "ride_uploaded_file_status_#{@ride_uploaded_file.id}", @ride_uploaded_file.processed
  end
end
