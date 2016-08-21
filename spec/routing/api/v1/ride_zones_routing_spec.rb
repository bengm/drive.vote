require 'rails_helper'

RSpec.describe Api::V1::ConversationsController, :type => :routing do
  describe 'routing' do

    it 'routes to conversations' do
      expect(get: '/api/1/ride_zones/42/conversations').to route_to('api/v1/ride_zones#conversations', id: '42')
    end

    it 'routes to create conversation' do
      expect(post: '/api/1/ride_zones/42/conversations').to route_to('api/v1/ride_zones#create_conversation', id: '42')
    end

    it 'routes to drivers' do
      expect(get: '/api/1/ride_zones/42/drivers').to route_to('api/v1/ride_zones#drivers', id: '42')
    end

    it 'routes to available nearby drivers' do
      expect(get: '/api/1/ride_zones/42/available_nearby_drivers').to route_to('api/v1/ride_zones#available_nearby_drivers', id: '42')
    end

    it 'routes to driver assign ride' do
      expect(post: '/api/1/ride_zones/42/assign_ride').to route_to('api/v1/ride_zones#assign_ride', id: '42')
    end

    it 'routes to rides' do
      expect(get: '/api/1/ride_zones/42/rides').to route_to('api/v1/ride_zones#rides', id: '42')
    end

    it 'routes to create_ride' do
      expect(post: '/api/1/ride_zones/42/rides').to route_to('api/v1/ride_zones#create_ride', id: '42')
    end
  end
end
