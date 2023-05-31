# Credential Master

`credential-master.rb` is a Ruby script that acts as a credential provider program. It listens for credential requests over a UNIX socket, authenticates with AWS, and generates session tokens with AWS Security Token Service (STS).

## Prerequisites

- Ruby (version X.X.X)
- `aws-sdk-core` gem (version X.X.X)

## Usage

1. Clone the repository and navigate to the project directory.

2. Create a YAML file named `aws-credentials.yml` with the following structure:

   ```yaml
   access_key_id: ACCESS_KEY_HERE
   secret_access_key: SECRET_ACCESS_KEY_HERE
   role_arn: "ARN_OF_THE_ROLE_TO_ASSUME"
   role_session_name: SESSION_NAME
   serial_number: "ARN_OF_MFA_DEVICE"
   region: "AWS_REGION"

Replace the placeholders with your actual AWS credentials, role ARN, session name, MFA device ARN, and AWS region.

Run the credential-master.rb script:

```zsh
ruby credential-master.rb
```

The script will start listening for credential requests on the specified UNIX socket path (/tmp/credential_provider_socket.sock by default).

In your application or program, establish a connection to the UNIX socket and send a request for credentials. The script will handle the authentication and provide session credentials in response.

Example request:

```ruby
require 'socket'
require 'json'

socket = UNIXSocket.new(Rails.configuration.aws[:dev_credentials][:socket_path])
socket.puts 'request_credentials'
credentials = JSON.parse(socket.gets)
session_token = credentials['session_token']
secret_access_key = credentials['secret_access_key']
access_key_id = Rails.configuration.aws[:dev_credentials][:access_key_id]
```

Replace `socket_path` with the actual path to the UNIX socket.

After receiving the credentials, you can use them for AWS SDK operations by configuring the SDK with the session token.

Example:

```ruby
Aws.config.update({
                    credentials: Aws::Credentials.new(access_key_id, secret_access_key, session_token),
                    access_key_id: access_key_id,
                    secret_access_key: secret_access_key,
                    session_token: session_token
                  })
```

License
This project is licensed under the MIT License.
