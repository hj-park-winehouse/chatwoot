# 커스텀 번역 기능 구현 완료

## 개요
Chatwoot에 구글 번역과 메타 번역을 사용한 커스텀 번역 기능을 구현했습니다. 엔터프라이즈 기능 없이도 실시간 번역이 가능하며, 원본과 번역된 내용을 모두 볼 수 있습니다.

## 구현된 파일들

### 1. 백엔드 서비스 파일들
- `/app/services/messages/translation_service.rb` - 메인 번역 서비스
- `/app/services/google_translate_service.rb` - 구글 번역 API 통합
- `/app/services/meta_translate_service.rb` - 메타 번역 API 통합
- `/app/controllers/api/v1/accounts/conversations/messages_controller.rb` - 번역 엔드포인트 업데이트

### 2. 프론트엔드 파일들
- `/app/javascript/dashboard/api/inbox/message.js` - MessageApi에 provider 파라미터 추가
- `/app/javascript/dashboard/store/modules/conversations/actions/messageTranslateActions.js` - 번역 액션 업데이트

## API 키 설정 방법

### 1. Google Translate API 설정
1. Google Cloud Console에서 Translate API 활성화
2. API 키 생성
3. `.env` 파일에 추가:
```bash
GOOGLE_TRANSLATE_API_KEY=your_actual_google_api_key_here
```

### 2. Meta Translate API 설정 (선택사항)
1. Meta API 접근 토큰 획득
2. `.env` 파일에 추가:
```bash
META_TRANSLATE_ACCESS_TOKEN=your_actual_meta_token_here
```

## 사용 방법

### 1. 메시지 번역하기
메시지에 텍스트가 있으면 컨텍스트 메뉴에서 "번역" 옵션이 나타납니다.

### 2. API 직접 호출
```javascript
// 구글 번역 사용 (기본값)
await MessageApi.translateMessage(conversationId, messageId, 'ko');

// 메타 번역 사용
await MessageApi.translateMessage(conversationId, messageId, 'ko', 'meta');
```

### 3. REST API 호출
```bash
curl -X POST https://your-domain/api/v1/accounts/{account_id}/conversations/{conversation_id}/messages/{message_id}/translate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "target_language": "ko",
    "provider": "google"
  }'
```

## 기능 특징

### 1. 자동 감지 및 번역
- 원본 언어 자동 감지
- 대상 언어로 자동 번역
- 번역 결과 저장 및 캐싱

### 2. 원본/번역 토글
- "원본 보기" / "번역 보기" 버튼으로 전환
- 기존 TranslationToggle 컴포넌트 활용

### 3. 오류 처리
- API 키 누락 시 graceful 실패
- 번역 실패 시 대체 서비스 시도
- 상세한 오류 로깅

### 4. 다중 번역 서비스
- 구글 번역 (기본값)
- 메타 번역 (백업)
- 확장 가능한 아키텍처

## 테스트 방법

### 1. 개발 서버 실행
```bash
# Rails 서버 시작
bundle exec rails server

# Vite 개발 서버 시작 (별도 터미널)
npm run dev
```

### 2. 번역 기능 테스트
1. Chatwoot 대화에서 메시지 작성
2. 메시지 우클릭 또는 메뉴에서 "번역" 선택
3. 번역된 내용 확인
4. "원본 보기" / "번역 보기" 토글 테스트

### 3. API 직접 테스트
```bash
# Rails 콘솔에서 테스트
rails console

# 번역 서비스 테스트
service = GoogleTranslateService.new("Hello world", "ko")
result = service.translate
puts result

# 메시지 번역 서비스 테스트
message = Message.find(your_message_id)
translation_service = Messages::TranslationService.new(
  message: message,
  target_language: "ko",
  provider: "google"
)
result = translation_service.perform
puts result
```

## 트러블슈팅

### 1. API 키 문제
- `.env` 파일에 올바른 API 키가 설정되었는지 확인
- 서버 재시작 후 테스트

### 2. 번역이 안 되는 경우
- Rails 로그 확인: `tail -f log/development.log`
- API 할당량 확인
- 네트워크 연결 상태 확인

### 3. 프론트엔드 오류
- 브라우저 개발자 도구 콘솔 확인
- 네트워크 탭에서 API 호출 상태 확인

## 확장 가능성

### 1. 새로운 번역 서비스 추가
```ruby
# 새 서비스 클래스 생성
class AmazonTranslateService
  def initialize(text, target_language, source_language = 'auto')
    # 구현
  end

  def translate
    # Amazon Translate API 호출
  end
end

# Messages::TranslationService에 추가
case provider
when 'amazon'
  AmazonTranslateService.new(content, target_language, source_language).translate
end
```

### 2. 언어 감지 개선
- 더 정확한 언어 감지 API 사용
- 사용자 선호 언어 설정 저장

### 3. 번역 품질 향상
- 컨텍스트 기반 번역
- 전문 용어 사전 적용
- 번역 품질 피드백 시스템

이제 구글 번역 API 키를 설정하시면 바로 사용할 수 있습니다!
