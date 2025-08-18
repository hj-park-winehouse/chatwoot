require 'socket'
require 'json'

class ScannerApiService
  SCANNER_HOST = 'scanner.ttgo.dev'
  SCANNER_PORT = 5014

  def self.get_subscribers_info(mobile)
    new.get_subscribers_info(mobile)
  end

  def get_subscribers_info(mobile)
    begin
      # TCP 소켓 연결
      socket = TCPSocket.new(SCANNER_HOST, SCANNER_PORT)
      
      # 요청 데이터 구성
      request_data = {
        type: 'request',
        command: 'subscribers_info',
        mobile: mobile
      }
      
      # JSON으로 변환 후 전송
      socket.write(request_data.to_json)
      socket.close_write
      
      # 응답 읽기 (최대 5초 대기)
      response = ''
      begin
        Timeout.timeout(5) do
          response = socket.read
        end
      rescue Timeout::Error
        Rails.logger.error "Scanner API timeout for mobile: #{mobile}"
        response = nil
      end
      
      socket.close
      
      # 응답 파싱
      if response.present?
        Rails.logger.info "Raw response string: #{response.inspect}"
        
        # 응답이 이미 문자열인 경우 다시 JSON 파싱
        if response.is_a?(String)
          parsed_response = JSON.parse(response)
        else
          parsed_response = response
        end
        
        Rails.logger.info "Parsed JSON response: #{parsed_response.inspect}"
        parse_scanner_response(parsed_response, mobile)
      else
        { error: 'No response from scanner API' }
      end
      
    rescue StandardError => e
      Rails.logger.error "Scanner API error for mobile #{mobile}: #{e.message}"
      { error: e.message }
    end
  end

  private

  def parse_scanner_response(response, mobile)
    Rails.logger.info "Raw response received: #{response.inspect}"
    
    # 응답이 문자열인 경우 JSON 파싱
    if response.is_a?(String)
      begin
        response = JSON.parse(response)
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON response: #{e.message}"
        return { error: 'Invalid JSON response', raw_response: response }
      end
    end
    
    # 새로운 JSON 형태로 응답이 오는 경우
    if response['status'] == 'success' && response['data']
      data = response['data']
      subscriber = data['subscriber']
      
      Rails.logger.info "Data section: #{data.inspect}"
      Rails.logger.info "Subscriber section: #{subscriber.inspect}"
      
      if subscriber
        parsed_data = {
          account_no: subscriber['account_no'],
          valid_date: subscriber['validDate'],
          # last_updated: subscriber['last_updated'],
          bill: subscriber['bill'],
          bank: subscriber['bank'],
          is_charge: data['is_charge']
        }
        
        Rails.logger.info "Parsed data: #{parsed_data.inspect}"
        
        { success: true, data: parsed_data }
      else
        { error: 'No subscriber data found', raw_response: response }
      end
    end
  end
end
