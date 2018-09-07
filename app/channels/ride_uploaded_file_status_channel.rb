class RideUploadedFileStatusChannel < ApplicationCable::Channel
  def subscribed
    logger.info "RideUploadedFileStatus connection from #{current_user.name} to ride uploaded file status #{params[:id]}"

    # Set up a stream specific to this ride uploaded file status
    stream_from "ride_uploaded_file_status_#{params[:id]}"
  end
end
