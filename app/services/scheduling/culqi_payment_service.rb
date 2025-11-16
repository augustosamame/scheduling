module Scheduling
  class CulqiPaymentService
    def initialize(booking, token_id)
      @booking = booking
      @token_id = token_id
      @event_type = booking.event_type
    end

    def process
      return { success: true } unless @event_type.requires_payment
      return { success: false, error: 'Token de pago requerido' } unless @token_id.present?

      begin
        # Create charge with Culqi API
        charge_data = {
          amount: @event_type.price_cents,
          currency_code: @event_type.price_currency,
          email: @booking.client.email,
          source_id: @token_id,
          description: "#{@event_type.title} - #{@booking.member.full_name}",
          installments: 0,
          capture: true,
          antifraud_details: build_antifraud_details
        }

        response = make_culqi_request('POST', '/v2/charges', charge_data)

        if response[:success]
          charge = response[:data]

          # Handle 3DS authentication if required
          if charge['outcome'] && charge['outcome']['type'] == 'issuer_requires_authentication'
            return {
              success: false,
              requires_3ds: true,
              three_d_secure_url: charge['outcome']['three_d_secure_url'],
              charge_id: charge['id'],
              message: 'Autenticación 3D Secure requerida'
            }
          else
            return process_successful_charge(charge)
          end
        else
          return { success: false, error: response[:error] }
        end
      rescue StandardError => e
        Rails.logger.error("Culqi payment error: #{e.message}")
        { success: false, error: 'Error procesando el pago. Intente nuevamente.' }
      end
    end

    def self.refund(payment)
      return unless payment.external_transaction_id.present?

      begin
        refund_data = {
          amount: payment.amount_cents,
          charge_id: payment.external_transaction_id,
          reason: 'solicitud_comprador'
        }

        response = new(payment.booking, nil).send(:make_culqi_request, 'POST', '/v2/refunds', refund_data)

        if response[:success]
          payment.update!(status: 'refunded')
          true
        else
          Rails.logger.error("Culqi refund failed: #{response[:error]}")
          false
        end
      rescue StandardError => e
        Rails.logger.error("Culqi refund error: #{e.message}")
        false
      end
    end

    # Verify charge status (useful for 3DS callbacks)
    def self.verify_charge(charge_id)
      service = new(nil, nil)
      response = service.send(:make_culqi_request, 'GET', "/v2/charges/#{charge_id}")

      if response[:success]
        response[:data]
      else
        nil
      end
    end

    private

    def process_successful_charge(charge)
      if charge['outcome'] && charge['outcome']['type'] == 'venta_exitosa'
        payment = @booking.create_payment!(
          amount_cents: charge['amount'],
          amount_currency: charge['currency_code'],
          status: 'completed',
          payment_method: 'card',
          payment_provider: 'culqi',
          external_transaction_id: charge['id'],
          paid_at: Time.current
        )

        @booking.update!(payment_status: 'paid')

        {
          success: true,
          payment: payment,
          charge_data: charge,
          message: 'Pago procesado exitosamente'
        }
      else
        error_message = charge['outcome'] ? charge['outcome']['user_message'] : 'El pago fue rechazado'
        {
          success: false,
          error: error_message || 'El pago fue rechazado'
        }
      end
    end

    def build_antifraud_details
      {
        address: @booking.member.team.location.address || 'Lima, Peru',
        address_city: @booking.member.team.location.city || 'Lima',
        country_code: 'PE',
        first_name: @booking.client.first_name || 'Cliente',
        last_name: @booking.client.last_name || 'Sistema',
        phone_number: @booking.client.phone || '999999999'
      }
    end

    def make_culqi_request(method, endpoint, data = nil)
      require 'net/http'
      require 'json'

      uri = URI("#{Culqi.base_url}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      case method.upcase
      when 'POST'
        request = Net::HTTP::Post.new(uri)
        request.body = data.to_json if data
      when 'GET'
        request = Net::HTTP::Get.new(uri)
      end

      request['Authorization'] = "Bearer #{Culqi.secret_key}"
      request['Content-Type'] = 'application/json'

      response = http.request(request)
      parsed_response = JSON.parse(response.body) rescue {}

      if response.code.to_i.between?(200, 299)
        { success: true, data: parsed_response }
      else
        error_message = parsed_response['user_message'] || parsed_response['message'] || 'Error en la comunicación con Culqi'
        Rails.logger.error "Culqi API Error: #{response.code} - #{parsed_response}"
        { success: false, error: error_message }
      end
    end
  end
end
