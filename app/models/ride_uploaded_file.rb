class RideUploadedFile < ApplicationRecord
  belongs_to :user
  has_one_attached :uploaded_csv

  validate :uploaded_file_must_be_csv

  after_create :enqueue_processing_dry_run

  private

  def uploaded_file_must_be_csv
    if uploaded_csv.attached? && !uploaded_csv.content_type.in?(%w(text/tab-separated-values))
      errors.add(:uploaded_csv, 'Must be in a comma or tab separated file format')
    end
  end

  def enqueue_processing_dry_run
    RideUploadedFileProcessingDryRunJob.perform_now(self.id)
  end
end
