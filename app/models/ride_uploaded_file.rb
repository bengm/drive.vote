class RideUploadedFile < ApplicationRecord
  belongs_to :user
  has_one_attached :uploaded_csv

  after_create :enqueue_processing_dry_run

  private

  def enqueue_processing_dry_run
    RideUploadedFileProcessingDryRunJob.perform_now(self.id)
  end
end
