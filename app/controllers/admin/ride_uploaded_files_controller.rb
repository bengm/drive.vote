class Admin::RideUploadedFilesController < Admin::AdminApplicationController

  def show
    @ride_uploaded_file = RideUploadedFile.find params[:id]
  end

  def new
    @ride_uploaded_file = RideUploadedFile.new
  end

  def create
    @ride_uploaded_file = RideUploadedFile.new(ride_file_params)

    @ride_uploaded_file.user = current_user

    if @ride_uploaded_file.save
      redirect_to admin_rides_csv_show_path id: @ride_uploaded_file.id
    else
      render :new
    end
  end

  def ride_file_params
    params.require(:ride_uploaded_file).permit(:uploaded_csv)
  end

end
