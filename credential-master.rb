require 'socket'
require 'aws-sdk-core'
require 'yaml'

# Load AWS credentials from YAML file
credentials = YAML.load_file('./aws-credentials.yml')

# Configure AWS SDK with access key and secret access key
Aws.config.update({
                    credentials: Aws::Credentials.new(credentials['access_key_id'], credentials['secret_access_key']),
                    region: credentials['region']
                  })

# Create an STS client
sts_client = Aws::STS::Client.new

# Create a UNIX socket server
socket_path = '/tmp/credential_provider_socket.sock'
File.unlink(socket_path) if File.exist?(socket_path)
server = UNIXServer.new(socket_path)

# Initialize session token and expiration time
session_token = nil
session_expiration = Time.now

# Assume a role and generate session token
session_duration_seconds = 3600 # The duration for which the session is valid (in seconds)
puts "Listening for credential requests on #{socket_path}..."

loop do
  # Wait for a new connection request
  socket = server.accept

  puts "Received a new connection request at #{Time.now}"

  # Check if session token is valid and not expired
  if session_token && session_expiration > Time.now
    puts 'Session already exists. Returning existing session credentials...'
    # Return the existing session token to the credential provider program
    credentials_json = {
      session_token: session_token,
      session_expiration: session_expiration.iso8601
    }.to_json
    socket.puts credentials_json
  else
    # Prompt user for current MFA code
    puts 'No active session found. Enter your current AWS MFA code:'
    mfa_code = gets.chomp

    begin
      # Assume the role
      assume_role_response = sts_client.assume_role({
                                                      role_arn: credentials['role_arn'],
                                                      role_session_name: credentials['role_session_name'],
                                                      serial_number: credentials['serial_number'],
                                                      token_code: mfa_code,
                                                      duration_seconds: session_duration_seconds
                                                    })

      # Extract the assumed role credentials
      assumed_role_credentials = assume_role_response.credentials

      # Store the new session token and expiration time
      session_token = assumed_role_credentials.session_token
      session_expiration = assumed_role_credentials.expiration

      # Format the credentials
      credentials_json = {
        session_token: session_token,
        session_expiration: session_expiration.iso8601
      }.to_json

      puts 'Session authentication successful. Returning session credentials...'
      # Return the credentials to the credential provider program
      socket.puts credentials_json
    rescue Aws::STS::Errors::AccessDenied
      puts 'Invalid MFA one-time pass code. Please wait for the next MFA code.'
      # Handle the error by informing the user to wait for the next MFA code
      socket.puts 'Invalid MFA one-time pass code. Please wait for the next MFA code.'
    end
  end

  socket.close
end
