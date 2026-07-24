# 카카오톡 데이터베이스 물리 스키마 DDL 및 최적화 SQL (5.1_solution.md)

이 문서는 [5_decesion.md](file:///Users/wooddang-mac/Desktop/code/intelliJ/chat_service/docs/database/5_decesion.md)의 핵심 아키텍처 결정 사항에 맞춰 실제로 구현된 데이터베이스 물리 DDL(Data Definition Language) 스크립트와 성능 최적화가 적용된 핵심 서비스 SQL 쿼리 템플릿을 정의합니다.

---

## 1. 물리 데이터베이스 DDL 스크립트 (MySQL/MariaDB 표준)

본 섹션은 설계 결정에 따라 신설 및 변경된 테이블들의 물리적 생성 DDL 및 인덱스 설정을 보여줍니다.

```sql
-- 1.1 사용자 생일 전용 테이블 (PROFILES에서 수직 분할)
CREATE TABLE `USER_BIRTHDAYS` (
    `user_id` BIGINT NOT NULL COMMENT '사용자 고유 식별자',
    `birth_month` TINYINT NOT NULL COMMENT '생일 월 (1~12)',
    `birth_day` TINYINT NOT NULL COMMENT '생일 일 (1~31)',
    `birth_year` SMALLINT NULL COMMENT '출생 연도 (나이 계산용, 선택 입력)',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`user_id`),
    CONSTRAINT `fk_user_birthdays_user_id` FOREIGN KEY (`user_id`) 
        REFERENCES `USERS` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 생일 조회를 위한 복합 B-Tree 인덱스 생성
CREATE INDEX `idx_user_birthdays_month_day` ON `USER_BIRTHDAYS` (`birth_month`, `birth_day`);


-- 1.2 탈퇴 회원 결제 데이터 보존을 위한 아카이빙 테이블 (물리 FK 연결 단절)
CREATE TABLE `GIFT_COUPON_ARCHIVES` (
    `id` BIGINT NOT NULL COMMENT '원본 GIFT_COUPONS.id 보존',
    `coupon_code` VARCHAR(100) NOT NULL COMMENT '마스킹 또는 암호화 처리된 쿠폰 코드',
    `sender_user_id` BIGINT NULL COMMENT '송신자 ID (탈퇴 회원 가능성으로 물리 FK 없음)',
    `receiver_user_id` BIGINT NULL COMMENT '수신자 ID (물리 FK 없음)',
    `product_id` BIGINT NOT NULL COMMENT '상품 고유 ID',
    `status` VARCHAR(50) NOT NULL COMMENT '최종 쿠폰 상태 (USED, EXPIRED 등)',
    `price_amount` DECIMAL(18, 2) NOT NULL COMMENT '결제 금액',
    `refund_recipient_role` VARCHAR(20) NOT NULL COMMENT '환불 대상자 구분 (SENDER, RECEIVER)',
    `created_at` TIMESTAMP NOT NULL COMMENT '최초 결제/선물 일시',
    `updated_at` TIMESTAMP NOT NULL COMMENT '최종 상태 변경 일시',
    `archived_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '아카이브 이관 완료 일시',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 감사 조회(정산 대조)를 위한 복합 인덱스 생성
CREATE INDEX `idx_gift_coupon_archives_status_date` ON `GIFT_COUPON_ARCHIVES` (`status`, `created_at`);
```

---

## 2. 도메인 요구사항 해결을 위한 최적화 SQL 쿼리

### 2.1 오늘 생일인 친구 목록 고속 조회 (도메인 16.1 해결)
사용자의 친구 목록 중 오늘이 생일인 친구들의 닉네임과 프로필 정보를 고속 조회합니다. `USER_BIRTHDAYS`에 생성된 복합 인덱스 `idx_user_birthdays_month_day`를 활용해 Range Scan이 작동하도록 함수 없는 쿼리로 설계했습니다.

```sql
-- 조회 기준일이 7월 15일인 경우의 쿼리 템플릿
SELECT 
    f.friend_user_id,
    p.nickname,
    p.profile_image_url,
    b.birth_year
FROM `FRIENDSHIPS` f
INNER JOIN `USER_BIRTHDAYS` b 
    ON f.friend_user_id = b.user_id
INNER JOIN `PROFILES` p 
    ON f.friend_user_id = p.user_id
WHERE f.user_id = :my_user_id                      -- 내 친구 필터링
  AND f.relationship_type = 'NORMAL'               -- 정상 관계인 친구만
  AND b.birth_month = 7                            -- 오늘 월 (인덱스 선두 컬럼 매칭)
  AND b.birth_day = 15;                            -- 오늘 일 (인덱스 매칭)
```

### 2.2 단체방 메시지별 안 읽은 수 동시성 해결 (도메인 10.1 해결)
대규모 단체방의 메시지 렌더링 시, 쓰기 락 경합이 발생하는 `unread_count` 컬럼의 실시간 업데이트를 배제하고, 참여자들의 읽음 상태(`last_read_message_id`)를 활용하여 읽기 시점에 동적 계산(Dynamic Read-time Calculate)을 적용한 쿼리입니다.

```sql
-- 특정 채팅방(chat_room_id = 10)에서 최근 작성된 메시지 100건과 각 메시지별 정확한 안 읽은 수 조회
SELECT 
    m.id AS message_id,
    m.sender_id,
    m.type,
    t.content,
    m.created_at,
    -- (전체 참여자 수) - (해당 메시지 ID보다 크거나 같은 last_read_message_id를 가진 참여자 수)
    (
        SELECT COUNT(1) 
        FROM `CHAT_ROOM_PARTICIPANTS` p_total 
        WHERE p_total.chat_room_id = m.chat_room_id 
          AND p_total.leaved_at IS NULL
    ) - (
        SELECT COUNT(1) 
        FROM `CHAT_ROOM_PARTICIPANTS` p_read 
        WHERE p_read.chat_room_id = m.chat_room_id 
          AND p_read.leaved_at IS NULL
          AND p_read.last_read_message_id >= m.id
    ) AS dynamic_unread_count
FROM `MESSAGES` m
INNER JOIN `TEXT_MESSAGES` t 
    ON m.id = t.message_id
WHERE m.chat_room_id = :chat_room_id
ORDER BY m.id DESC
LIMIT 100;
```

### 2.3 탈퇴 회원 법적 보존 데이터 격리 이관 배치 (도메인 2.1 해결)
회원이 탈퇴한 지 유예 기간(예: 14일)이 경과했을 때, 법적으로 5년간 보존해야 하는 결제/기프티콘 데이터를 안전하게 보존 구역으로 하드 무브(Hard Move)하는 트랜잭션 쿼리입니다.

```sql
-- 1단계: 트랜잭션 시작
START TRANSACTION;

-- 2단계: 탈퇴 회원(WITHDRAWING 회원) 중 유예기간이 지난 대상의 쿠폰 데이터를 아카이빙 테이블로 복사
-- 이 과정에서 쿠폰 코드는 마스킹(Masking)하여 암호화/비식별화 처리
INSERT INTO `GIFT_COUPON_ARCHIVES` (
    id, 
    coupon_code, 
    sender_user_id, 
    receiver_user_id, 
    product_id, 
    status, 
    price_amount, 
    refund_recipient_role, 
    created_at, 
    updated_at, 
    archived_at
)
SELECT 
    c.id,
    CONCAT(LEFT(c.coupon_code, 4), '-****-****') AS coupon_code, -- 마스킹 예시
    c.sender_user_id,
    c.receiver_user_id,
    c.product_id,
    c.status,
    c.price_amount,
    c.refund_recipient_role,
    c.created_at,
    c.updated_at,
    NOW()
FROM `GIFT_COUPONS` c
INNER JOIN `USERS` u 
    ON (c.sender_user_id = u.id OR c.receiver_user_id = u.id)
WHERE u.status = 'WITHDRAWING'
  AND u.status_updated_at <= DATE_SUB(NOW(), INTERVAL 14 DAY);

-- 3단계: 복사 완료 후 메인 서비스 테이블(GIFT_COUPONS)에서 해당 데이터 삭제 (Hard Delete)
-- 물리적 FK가 차단되어 있으므로 다른 테이블 영향 없이 정합성을 유지하며 파기
DELETE c 
FROM `GIFT_COUPONS` c
INNER JOIN `USERS` u 
    ON (c.sender_user_id = u.id OR c.receiver_user_id = u.id)
WHERE u.status = 'WITHDRAWING'
  AND u.status_updated_at <= DATE_SUB(NOW(), INTERVAL 14 DAY);

-- 4단계: 트랜잭션 커밋
COMMIT;
```

### 2.4 메시지 중복 전송 방지 멱등성 제어 (도메인 11.1 해결)
모바일 네트워크가 단절되었다가 복구되었을 때 동일한 메시지 전송 패킷이 여러 번 서버에 인입되더라도 데이터베이스 레벨에서 중복 생성을 막는 멱등성 보장 쿼리 예시입니다. `client_message_token` 유니크 인덱스를 활용합니다.

```sql
-- INSERT 시 Unique Constraint Error가 나더라도 애플리케이션으로 에러를 반환하지 않고 
-- 무시(IGNORE)하거나 기존 건을 업데이트하여 중복 생성을 차단하는 쿼리
INSERT IGNORE INTO `MESSAGES` (
    `chat_room_id`, 
    `sender_id`, 
    `type`, 
    `client_message_token`, 
    `unread_count`, 
    `created_at`
) VALUES (
    :chat_room_id, 
    :sender_id, 
    'TEXT', 
    :client_msg_uuid_token, -- 클라이언트가 전송한 고유 메시지 UUID
    :room_member_count, 
    NOW()
);

-- 만약 중복 입력이 발생한 경우, 0 rows affected를 반환하므로 애플리케이션에서 중복을 안전하게 감지
```
