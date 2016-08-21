require 'rails_helper'

RSpec.describe Api::V1::RideZonesController, :type => :controller do
  describe 'conversations' do
    let!(:notinrz) { create :conversation }
    let(:rz) { create :ride_zone }
    let!(:c1) { create :conversation, ride_zone: rz, status: :in_progress }
    let!(:c2) { create :conversation, ride_zone: rz, status: :ride_created }
    let!(:c3) { create :conversation, ride_zone: rz, status: :closed }

    it 'is successful' do
      get :conversations, params: {id: rz.id}
      expect(response).to be_successful
    end

    it 'returns active conversations' do
      get :conversations, params: {id: rz.id}
      expect(JSON.parse(response.body)['response']).to match_array([c1.api_json(true), c2.api_json(true)])
    end

    it 'returns requested conversations' do
      get :conversations, params: {id: rz.id, status: :ride_created}
      expect(JSON.parse(response.body)['response']).to match_array([c2.api_json(true)])
    end

    it 'returns multitype requested conversations' do
      get :conversations, params: {id: rz.id, status: 'ride_created, closed'}
      expect(JSON.parse(response.body)['response']).to match_array([c2.api_json(true), c3.api_json(true)])
    end

    it '404s for missing ride zone' do
      get :conversations, params: {id: 0}
      expect(response.status).to eq(404)
    end
  end

  describe 'create conversation' do
    let(:rz) { create :ride_zone }
    let(:user) { create :driver_user, ride_zone: rz }
    let(:body) { 'can you go to south side?' }
    let(:convo) { create :conversation }

    before :each do
      allow(Conversation).to receive(:create_from_staff).and_return(convo)
    end

    it 'is successful' do
      post :create_conversation, params: {id: rz.id, user_id: user.id, body: body}
      expect(response).to be_successful
    end

    it 'calls conversation model and responds with json' do
      expect(Conversation).to receive(:create_from_staff).and_return(convo)
      post :create_conversation, params: {id: rz.id, user_id: user.id, body: body}
      expect(JSON.parse(response.body)['response']).to eq(convo.api_json)
    end

    it 'handles error from conversation' do
      expect(Conversation).to receive(:create_from_staff).and_return('error')
      post :create_conversation, params: {id: rz.id, user_id: user.id, body: body}
      expect(response.status).to eq(408)
      expect(JSON.parse(response.body)['error']).to eq('error')
    end

    it 'validates user id' do
      post :create_conversation, params: {id: rz.id, user_id: 0}
      expect(response.status).to eq(404)
    end

    it '404s for missing ride zone' do
      get :create_conversation, params: {id: 0}
      expect(response.status).to eq(404)
    end
  end

  describe 'drivers' do
    let!(:rz) { create :ride_zone }
    let!(:u1) { create :driver_user, ride_zone: rz }
    let!(:u2) { create :driver_user, ride_zone: rz }
    let!(:ride) { create :ride, ride_zone: rz }
    let(:rz2) { create :ride_zone }
    let!(:notinrz) { create :driver_user, ride_zone: rz2 }

    it 'is successful' do
      get :drivers, params: {id: rz.id}
      expect(response).to be_successful
    end

    it 'returns drivers for ride zone' do
      get :drivers, params: {id: rz.id}
      resp = JSON.parse(response.body)['response']
      expect(resp).to match_array([u1.api_json.as_json, u2.api_json.as_json])
    end

    it 'succeeds assigning rides to drivers' do
      post :assign_ride, params: {id: rz.id, driver_id: u1.id, ride_id: ride.id}
      expect(response).to be_successful
    end

    it 'assigns the ride to driver' do
      post :assign_ride, params: {id: rz.id, driver_id: u1.id, ride_id: ride.id}
      expect(u1.reload.active_ride).to_not be_nil
    end

    it 'removes if already assigned' do
      ride.assign_driver(u2)
      post :assign_ride, params: {id: rz.id, driver_id: u1.id, ride_id: ride.id}
      expect(response).to be_successful
      expect(ride.reload.driver).to eq(u1)
    end

    it '404s for missing ride zone' do
      get :drivers, params: {id: 0}
      expect(response.status).to eq(404)
    end

    it '404s for missing driver' do
      post :assign_ride, params: {id: rz.id, driver_id: 0, ride_id: ride.id}
      expect(response.status).to eq(404)
    end

    it '404s for missing ride' do
      post :assign_ride, params: {id: rz.id, driver_id: u1.id, ride_id: 0}
      expect(response.status).to eq(404)
    end
  end

  describe 'nearby drivers' do
    let!(:rz) { create :ride_zone }

    before :each do
      allow(User).to receive(:available_nearby_drivers).and_return([])
    end

    it 'is successful' do
      get :available_nearby_drivers, params: {id: rz.id, latitude: 34, longitude: -122}
      expect(response).to be_successful
    end

    it 'returns driver for ride zone' do
      d = create :driver_user, ride_zone: rz
      expect(User).to receive(:available_nearby_drivers).and_return([d])
      get :available_nearby_drivers, params: {id: rz.id, latitude: 34, longitude: -122}
      resp = JSON.parse(response.body)['response']
      expect(resp).to match_array([d.api_json.as_json])
    end

    it 'complains missing lat' do
      get :available_nearby_drivers, params: {id: rz.id, longitude: -122}
      expect(response.status).to eq(400)
    end

    it 'complains missing long' do
      get :available_nearby_drivers, params: {id: rz.id, latitude: 34}
      expect(response.status).to eq(400)
    end
  end

  describe 'rides' do
    let!(:rz) { create :ride_zone }
    let!(:r_incomplete) { create :ride, ride_zone: rz }
    let!(:r_waiting) { create :waiting_ride, ride_zone: rz }
    let!(:r_assigned) { create :assigned_ride, ride_zone: rz }
    let!(:r_picked_up) { create :picked_up_ride, ride_zone: rz }
    let!(:r_complete) { create :complete_ride, ride_zone: rz }
    let(:rz2) { create :ride_zone }
    let!(:notinrz) { create :waiting_ride, ride_zone: rz2 }

    it 'is successful' do
      get :rides, params: {id: rz.id}
      expect(response).to be_successful
    end

    it 'returns rides for ride zone' do
      get :rides, params: {id: rz.id}
      resp = JSON.parse(response.body)['response']
      expect(resp).to match_array([r_waiting.api_json, r_assigned.api_json, r_picked_up.api_json])
    end

    it 'returns multitype requested conversations' do
      get :rides, params: {id: rz.id, status: 'driver_assigned, picked_up'}
      resp = JSON.parse(response.body)['response']
      expect(resp).to match_array([r_assigned.api_json, r_picked_up.api_json])
    end

    it '404s for missing ride zone' do
      get :rides, params: {id: 0}
      expect(response.status).to eq(404)
    end
  end

  describe 'create ride' do
    let!(:rz) { create :ride_zone }
    let!(:voter) { create :voter_user }

    it 'is successful' do
      post :create_ride, params: {id: rz.id, ride: { voter_id: voter.id, name: 'foo'} }
      expect(response).to be_successful
    end

    it 'creates a new ride for the ride zone' do
      expect {
          post :create_ride, params: {id: rz.id, ride: { voter_id: voter.id, name: 'foo'} }
      }.to change(Ride, :count).by(1)
      expect(Ride.first.name).to eq('foo')
    end

    it 'does not create a ride with missing voter_id' do
      expect {
          post :create_ride, params: {id: rz.id, ride: { name: 'foo' } }
      }.to change(Ride, :count).by(0)
      expect(JSON.parse(response.body)['error']).to include('voter')
    end
  end
end
