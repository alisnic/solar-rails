require 'spec_helper'

RSpec.describe SolarRails::Devise do
  let(:api_map) { Solargraph::ApiMap.new }

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with("db/schema.rb").and_return("")
    Solargraph::Convention.register SolarRails::Convention
  end

  it "includes devise modules" do
    map = use_workspace "./spec/rails5" do |root|
      root.write_file 'app/models/user.rb', <<~RUBY
        class User < ActiveRecord::Base
          devise :registerable, :confirmable, :timeoutable, timeout_in: 12.hours
        end
        User.new.conf
      RUBY

      root.write_file 'app/controllers/application_controller.rb', <<~RUBY
        class ApplicationController < ActionController::Base
          def index
            curr
            sign
          end
        end
      RUBY
    end

    expect(completion_at('./app/models/user.rb', [3, 13], map)).to include("confirm")
    expect(completion_at('./app/controllers/application_controller.rb', [3, 7], map)).to include("sign_in_and_redirect")
    expect(completion_at('./app/controllers/application_controller.rb', [2, 7], map)).to include("current_user")
  end
end