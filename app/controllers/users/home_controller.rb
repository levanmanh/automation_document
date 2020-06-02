require "google/apis/drive_v3"
require "google/api_client/client_secrets.rb"

module Users
  class HomeController < BaseController
    before_action :authenticate_user!

    def index
    end
  end
end
