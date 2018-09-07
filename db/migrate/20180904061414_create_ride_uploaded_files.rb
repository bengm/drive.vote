class CreateRideUploadedFiles < ActiveRecord::Migration[5.2]
  def change
    create_table :ride_uploaded_files do |t|
      t.integer :user_id, null: false
      t.boolean :processed, default: false

      t.timestamps
    end
    add_index(:ride_uploaded_files, :user_id)
  end
end
