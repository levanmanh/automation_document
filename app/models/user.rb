class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  devise :omniauthable, omniauth_providers: [:google_oauth2]

  store :settings, accessors: [:provider_scopes]

  def self.from_omniauth(request)
    auth = request.env["omniauth.auth"]
    scopes = request.env["omniauth.params"]["scope"]
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.email = auth.info.email
    user.password ||= Devise.friendly_token[0, 20]
    user.refresh_token = auth.credentials.refresh_token
    user.access_token = auth.credentials.token
    user.expires_at = auth.credentials.expires_at
    binding.pry
    user.provider_scopes = "#{user.provider_scopes},#{scopes}" if scopes.present?
    user.save
    user
  end
end
