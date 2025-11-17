class ApplicationController < ActionController::Base
  # Browser restriction disabled for development/testing
  # allow_browser versions: :modern

  # Simple authentication for testing (NOT for production!)
  # In production, use Devise, Sorcery, or another authentication gem
  helper_method :current_user

  def current_user
    # For testing, get user from session or default to admin user
    @current_user ||= begin
      if session[:user_id]
        User.find_by(id: session[:user_id])
      else
        # Default to admin user for easy testing
        User.find_by(email: 'admin@test.com')
      end
    end
  end

  # Helper to switch users for testing different roles
  def switch_user(email)
    user = User.find_by(email: email)
    if user
      session[:user_id] = user.id
      @current_user = user
    end
  end
end
