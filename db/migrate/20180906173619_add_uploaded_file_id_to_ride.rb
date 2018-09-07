class AddUploadedFileIdToRide < ActiveRecord::Migration[5.2]
  def change
    add_column :rides, :ride_uploaded_file_id, :integer
    add_index(:rides, :ride_uploaded_file_id)
  end
end
