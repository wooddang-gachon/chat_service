# 카카오톡 데이터베이스 설계 의사결정 이력서 (5_decesion.md)

이 문서는 [2_domain.md](file:///Users/wooddang-mac/Desktop/code/intelliJ/chat_service/docs/database/2_domain.md)에 기술된 도메인 비즈니스 요구사항 및 해결 과제들이 [3.3_kakaotalk_db_erd_woo_v2.md](file:///Users/wooddang-mac/Desktop/code/intelliJ/chat_service/docs/database/3.3_kakaotalk_db_erd_woo_v2.md) 설계에 최종적으로 어떻게 반영되었는지 기술적인 의사결정 근거를 기록하고 동기화한 문서입니다.

---

## 1. 주요 최종 아키텍처 결정 사항 (Key Architecture Decisions)

### 1.1 생일자 친구 목록 조회 성능 최적화 (도메인 16.1 해결)
- **고민**: 기존 `PROFILES` 테이블에 생년월일(`birthday`) 컬럼을 두고 `MONTH(birthday)`와 같은 함수를 통해 필터링하면 B-Tree 인덱스가 작동하지 않아 전체 행을 읽어야 하는 Full Table Scan이 유발되었습니다.
- **결정**: 생일 정보만을 수직 분할하여 전용 테이블 `USER_BIRTHDAYS`를 신설하는 1:1 관계 모델을 구축했습니다.
  - 월(`birth_month`)과 일(`birth_day`) 컬럼을 별도로 분리하고, 이에 복합 B-Tree 인덱스 `(birth_month, birth_day)`를 지정했습니다.
  - 이로써 생일자 친구 쿼리가 `WHERE birth_month = ? AND birth_day = ?` 조건으로 인덱스 범위 스캔(Range Scan)되어 O(log N) 성능을 보장받도록 최적화했습니다.

### 1.2 법적 보존 데이터(결제 등)의 격리 아카이빙 (도메인 2.1 해결)
- **고민**: 개인정보 보호법에 따라 탈퇴 회원의 개인정보는 즉시 파기해야 하지만, 세법 및 전자상거래법에 따라 결제/선물 관련 이력 데이터는 5년간 의무 보존해야 합니다. 만약 메인 `USERS` 테이블과 물리적 참조 무결성(FK)을 맺고 있는 데이터를 하드 딜리트하면 정합성 에러가 발생합니다.
- **결정**: 탈퇴 회원의 결제/선물 데이터를 격리 보존하기 위해 `GIFT_COUPON_ARCHIVES` 테이블을 신설했습니다.
  - 회원이 탈퇴하고 유예 기간(14일)이 지나면, 해당 회원의 거래 이력을 `GIFT_COUPONS`에서 `GIFT_COUPON_ARCHIVES`로 Hard Move(이관)시킵니다.
  - 이때 식별 데이터는 마스킹 처리하며, RDB 무결성 오류를 피하기 위해 `USERS` 및 `GIFT_COUPONS`와의 **물리적 외래키(FK) 제약조건을 완전히 단절**하여 로그성으로 보관합니다. 이로써 법적 감사 보존 의무와 개인정보 파기 정책을 완벽하게 호환시켰습니다.

### 1.3 타겟 마케팅 분석을 위한 BigQuery 이관 방안 보류 (도메인 4.2 대처)
- **고민**: 장바구니에 담은 채 3일간 구매하지 않은 20대 유저 필터링 등 다차원 마케팅 분석을 실시간 트랜잭션 DB(MySQL)에서 조회하면 디스크 I/O 병목 및 서비스 가용성 저하가 우려되어 BigQuery 오프로딩 설계가 고려되었습니다.
- **결정**: 비즈니스 우선순위 조율에 따라 BigQuery 동기화 파이프라인 아키텍처 적용은 **최종 보류**하기로 결정했습니다.
  - 대안으로 메인 RDB 내부에서 검색 성능을 최대한 확보하기 위해 `CART_ITEMS(status, updated_at)` 및 `PROFILES(gender)`에 인덱스 필터 전략을 남겨두는 수준으로 타협하고 성능 부하 모니터링을 지속하기로 처리했습니다.

---

## 2. 도메인 요구사항 - DB 스키마 매핑 매트릭스 (Traceability Matrix)

[2_domain.md](file:///Users/wooddang-mac/Desktop/code/intelliJ/chat_service/docs/database/2_domain.md)의 비즈니스 해결 과제들이 [3.3_kakaotalk_db_erd_woo_v2.md](file:///Users/wooddang-mac/Desktop/code/intelliJ/chat_service/docs/database/3.3_kakaotalk_db_erd_woo_v2.md)의 어떤 데이터 구조와 의사결정으로 해결되었는지 명시합니다.

| 도메인 ID | 요구사항 개요 | RDB 물리 테이블 / 인덱스 / 스키마 설계 솔루션 |
| :--- | :--- | :--- |
| **1.1** | 단일 기기 세션 관리 | `USER_SESSIONS` 테이블 설계, `session_token` 유니크 인덱스 지정 및 중복 기기 세션 비활성화 로직 적용 |
| **1.2** | 기기 이전 백업/복원 | `USER_BACKUPS` 테이블에 암호화 키 해시 보관, `expires_at` 컬럼 기반 14일 자동 만료 배치 연계 |
| **2.1** | 법적 보존 & 탈퇴 정합성 | 회원 status 변경(WITHDRAWING) 및 개인정보 난수화/마스킹 처리, `GIFT_COUPON_ARCHIVES` 이관 및 FK 차단 설계 |
| **2.2** | 탈퇴 회원 메시지 보존 | `MESSAGES.sender_id` 보존, 탈퇴 유저(빈 껍데기 레코드) 참조 시 UI 상 "알 수 없음" 분기 렌더링 처리 |
| **3.1** | 초고빈도 행동 로그 격리 | `BEHAVIOR_LOGS` 테이블 물리 FK 제약조건 단절, Kafka/NoSQL 아키텍처 이원화 적재를 고려한 논리 스키마 준수 |
| **4.1** | 마케팅 기여도 영속화 | `USER_ACQUISITIONS` 테이블 구축을 통한 UTM 유입 파라미터 정보 영속 보관 |
| **4.2** | 타겟 마케팅 필터링 | `CART_ITEMS.status` 코드화 및 `CART_ITEMS(status, updated_at)` 복합 인덱스, `PROFILES(gender)` 인덱싱 전략 적용 *(BigQuery 오프로딩은 최종 보류)* |
| **6.1** | 오픈채팅 익명성 & 차단 | 가명 전용 `OPEN_CHAT_PARTICIPANT_PROFILES` 1:1 분리, 실제 user_id 맵핑 기준 `OPEN_CHAT_BLACKLISTS` 적용 |
| **7.1** | 알림톡 발송 정산 무결성 | `BIZ_MESSAGES`와 `BIZ_MESSAGE_DELIVERIES` 1:1 분리 설계, Insert-Only 로그성 적재를 통한 감사 추적성 보장 |
| **8.1** | 기프티콘 상태 전이 관리 | `GIFT_COUPONS` 발급 정보 및 `GIFT_COUPON_HISTORIES` 이력 엔티티 분리 설계를 통한 ACID 상태 전이 추적 |
| **9.1** | 메시지 수정 히스토리 | `MESSAGES` 수정 상태 플래그(`is_edited`) 지정, 변경 전 원본은 1:N 관계인 `MESSAGE_EDIT_HISTORIES`로 격리 분할 |
| **10.1** | 단체방 안 읽은 수 동시성 | 참여자별 `last_read_message_id`만 갱신, 안 읽은 개수는 쿼리 타임 동적 연산(Read-time Dynamic Calculation)하여 로우 락 병목 방지 |
| **11.1** | 메시지 멱등성 보장 | 클라이언트 토큰 `client_message_token` 컬럼에 유니크 인덱스를 지정하여 중복 적재 원천 차단 |
| **12.1** | 멀티프로필 친구 목록 로딩 | `MULTI_PROFILE_MAPPINGS`에 복합 인덱스 `(friendship_id, multi_profile_id)`를 지정하여 다중 조인 오버헤드 최소화 |
| **13.1** | 채팅방 개인화 설정 확장 | `CHAT_ROOM_PERSONAL_SETTINGS` 수직 분할(1:1 개별 테이블 전략)로 주 테이블 가로 행 밀도 확보 및 정렬 속도 보장 |
| **14.1** | 대화방 비우기/나가기 격리 | `CHAT_ROOM_PARTICIPANTS`에 `cleared_at`, `leaved_at`, `joined_at`을 두어 공용 메시지 풀에서 동적 조건 필터링 |
| **15.1** | 미디어 파일 만료(TTL) | `MEDIA_MESSAGES` 수직 분할로 로우 오버플로우 방지, 원본/썸네일 개별 만료일 관리 및 톡서랍(`DRAWER_SUBSCRIPTIONS`) 연계 |
| **16.1** | 다차원 친구 목록 조회 | `USER_BIRTHDAYS` 테이블 신설 및 `(birth_month, birth_day)` 복합 인덱스 활용, `PROFILES`에서 생일 데이터 완전 분리 |
