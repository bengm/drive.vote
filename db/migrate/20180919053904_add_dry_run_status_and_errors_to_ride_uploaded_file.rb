class AddDryRunStatusAndErrorsToRideUploadedFile < ActiveRecord::Migration[5.2]
  def change
    add_column :ride_uploaded_files, :dry_run_completed, :boolean
    add_column :ride_uploaded_files, :dry_run_errors, :json
  end
end
