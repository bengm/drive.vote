require 'rails_helper'

RSpec.describe 'admin/conversations/index', type: :view do
  before(:each) do
    allow(view).to receive(:current_user).and_return( create(:user)  )
    rz = create :ride_zone
    assign(:conversations, [create(:conversation, ride_zone: rz), create(:conversation, ride_zone: rz)])
  end

  it "renders a list of rides" do
    allow(view).to receive_messages(:will_paginate => nil)
    render
  end
end
