class AuthenticateUser
  def initialize(email, password)
    @email = email
    @password = password
  end

  # Service entry point
  def call
    return {} unless user
    {
      result: JsonWebToken.encode(user_id: user.id)
    }
  end

  private

  attr_reader :email, :password

  # Verify user credentials
  def user
    user = User.find_by(email: email)
    return user if user && user.authenticate(password)

    # Raise Authentication error if credentials are invalid
    raise(
      ExceptionHandler::AuthenticationError,
      'Invalid credentials'
    )
  end
end
