Rails.application.routes.draw do
  # Mount at /book to mirror real-world usage
  # This avoids route conflicts with main app routes
  mount Scheduling::Engine => "/book"

  # Simple root page for testing
  root to: proc { |env| [200, {}, ["<html><body><h1>Scheduling Engine Test App</h1><p>Visit <a href='/book/admin'>Admin Panel</a></p><hr><p><strong>Switch User (for testing):</strong></p><ul><li><a href='/switch_user?email=admin@test.com'>Admin User</a></li><li><a href='/switch_user?email=manager@test.com'>Manager User</a></li><li><a href='/switch_user?email=doctor@test.com'>Member User</a></li></ul></body></html>"]] }

  # Helper route to switch users for testing
  get '/switch_user', to: proc { |env|
    request = ActionDispatch::Request.new(env)
    email = request.params['email']
    user = User.find_by(email: email)

    if user
      request.session[:user_id] = user.id
      [302, {'Location' => '/book/admin'}, ["Redirecting..."]]
    else
      [404, {}, ["User not found"]]
    end
  }
end
