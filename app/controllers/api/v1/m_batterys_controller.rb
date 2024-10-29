require 'digest'
require 'openssl'
require 'jwt'
require 'time'

JWT.configuration.strict_base64_decoding = true

class Api::V1::MBatterysController < ApplicationController
    before_action :authenticate_moon_battery, only: [:Register]
    before_action :authenticate_config_battery, only: [:configuration]

    def index
        @m_batterys = Battery.all
        render json: @m_batterys
    end

    def Register
        mac_address = params[:mac_address]
        if mac_address.blank?
            return render json: { error: 'MAC address is blank'}, status: :unprocessable_entity
        end
        mac_existing = Battery.find_by(mac_address: mac_address)
        if mac_existing
            return render json: { error: 'MAC address already stored'}, status: :unprocessable_entity
        else
            last_b = Battery.last
            if last_b.nil? || last_b.id.nil?
                last_b = 0
            else
                last_b = last_b.id+1
            end
            serial_number = '007672' + last_b.to_s

            timestamp = Time.now.utc

            digest = OpenSSL::Digest::SHA256.new  # Use SHA-256 as the hashing algorithm     
            private_key_content = File.read("private_key.pem")
            rsa_private_key = OpenSSL::PKey::RSA.new(private_key_content)
            data = "#{serial_number}:#{timestamp}"
            signature = rsa_private_key.sign(digest,data)
            sig = Base64.encode64(signature)
            public_key_content = File.read("public_key.pem")
            rsa_public_key = OpenSSL::PKey::RSA.new(public_key_content)
            sha256_hash = Digest::SHA256.hexdigest(serial_number)
            current_battery = Battery.create(mac_address: mac_address, serial_number: sha256_hash)

            return render json: {serial_number: serial_number, timestamp: timestamp, signature: sig}, status: :ok
        end
    end

    def ping
        token= params[:token]
        if token.blank?
            return render json: { error: 'Authentication required' }, status: :unauthorized
        end
        digest = OpenSSL::Digest::SHA256.new  # Use SHA-256 as the hashing algorithm
        public_key_content = File.read("public_key.pem")
        rsa_public_key = OpenSSL::PKey::RSA.new(public_key_content)
        decoded_token = JWT.decode(token, rsa_public_key, true, { algorithm: 'RS256' })

        serial_number = decoded_token[0]["serial"]
       
        serial_number_hashed = Digest::SHA256.hexdigest(serial_number)
        serial_number_existing = Battery.find_by(serial_number: serial_number_hashed)
        if serial_number_existing
            serial_number_existing.update(last_contact: Time.now.utc)
            render json: { message: 'Ping received' }, status: :ok
            else
                render json: { message: 'MoonBattery not found' }, status: :unauthorized
            end
    end

    def configuration
        configurations = params[:configurations] || {}
        if configurations.blank?
            return render json: { error: 'configuration required' }, status: :unprocessable_entity
        end
        if (Time.now.utc -  @m_batterys.last_contact).abs > 60.minutes
            return render json: { error: 'invalid access' }, status: :unauthorized
        end
        @m_batterys.configurations ||= {}  # Initialize configurations if nil
        configurations.each do |key, value|
            @m_batterys.configurations[key] = value
        end
        @m_batterys.save!
        render json: { message: "Configuration updated" }, status: :ok
    end

    private
    def authenticate_config_battery
        token = request.headers['Authorization']&.split(' ')&.last
        digest = OpenSSL::Digest::SHA256.new  # Use SHA-256 as the hashing algorithm
        public_key_content = File.read("public_key.pem")
        rsa_public_key = OpenSSL::PKey::RSA.new(public_key_content)
        begin
            decoded_token = JWT.decode(token, rsa_public_key, true, { algorithm: 'RS256' })
            serial_number = decoded_token[0]["serial"]
            serial_number_hashed = Digest::SHA256.hexdigest(serial_number)
            @m_batterys = Battery.find_by(serial_number: serial_number_hashed)
            render json: { error: 'MoonBattery not found' }, status: :not_found unless @m_batterys
        rescue JWT::DecodeError, JWT::ExpiredSignature
            render json: { error: 'Invalid or expired token' }, status: :unauthorized
        end
    end

    def authenticate_moon_battery
        mac_address = params[:mac_address]
        timestamp = params[:timestamp]
        received_signature = params[:signature]
        unless mac_address && timestamp && received_signature
            return render json: { error: 'Authentication required' }, status: :unauthorized
        end

        if (Time.now.utc - Time.parse(timestamp)).abs > 5.minutes
          return render json: { error: 'Timestamp expired' }, status: :unauthorized
        end

        data = "#{mac_address}:#{timestamp}"
        received_signature = Base64.decode64(received_signature)
        digest = OpenSSL::Digest::SHA256.new  # Use SHA-256 as the hashing algorithm
        public_key_content = File.read("public_key.pem")
        rsa_public_key = OpenSSL::PKey::RSA.new(public_key_content)

        valid = rsa_public_key.verify(digest, received_signature, data)
        puts valid
        if valid == false
            return render json: { error: 'Invalid signature' }, status: :unauthorized
        end
    end
end
