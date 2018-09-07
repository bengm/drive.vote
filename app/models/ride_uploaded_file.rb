class RideUploadedFile < ApplicationRecord
  belongs_to :user
  has_one_attached :uploaded_csv

end
