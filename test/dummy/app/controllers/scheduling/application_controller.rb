module Scheduling
  class ApplicationController < ::ApplicationController
    # Engine-specific controller logic
    protect_from_forgery with: :exception

    # Default layout for scheduling pages
    layout 'scheduling/application'

    # Engine-specific error handling
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    private

    def record_not_found
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end
end
