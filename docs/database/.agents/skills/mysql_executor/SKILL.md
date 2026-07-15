---
name: mysql_executor
description: AI가 Node.js와 mysql2 패키지를 활용해 로컬 또는 원격 MySQL 데이터베이스에 직접 SQL 쿼리(DDL/DML)를 자율적으로 실행하고 결과를 확인하는 스킬입니다.
---

# MySQL Query Executor Skill

이 스킬은 에이전트가 데이터베이스 무결성을 직접 확인하거나, 테스트 데이터를 삽입해보고 쿼리를 던져보는 용도로 사용합니다.

## 전제 조건
- 프로젝트 루트 디렉토리의 `.env` 파일에 `DATABASE_URL` 환경 변수가 정의되어 있어야 합니다.
  - 형식: `DATABASE_URL="mysql://유저명:패스워드@호스트:포트/DB명"`
- 프로젝트에 `mysql2` 및 `dotenv` 패키지가 설치되어 있어야 합니다.

## 사용 방법

### 1. 일반 SQL 실행 (영구 반영)
실제 DDL 테이블 생성이나 수정, 마이그레이션이 필요할 때 사용합니다.
```bash
node .agents/skills/mysql_executor/scripts/run_query.js "실행할 SQL 쿼리"
```

### 2. 안전한 테스트 실행 (트랜잭션 롤백)
데이터의 추가/수정/삭제를 동반하는 테스트 쿼리를 던져보고, DB 데이터 상태는 원래대로 보존(롤백)하고 싶을 때 사용합니다. 세미콜론(`;`)으로 여러 쿼리를 묶어 한 번에 실행하고 최종 롤백합니다.
```bash
node .agents/skills/mysql_executor/scripts/test_query.js "INSERT INTO users (nickname) VALUES ('test'); SELECT * FROM users WHERE nickname = 'test';"
```

## 에러 처리 및 보고 규정
- 모든 스크립트 실행 결과는 JSON 문자열 형식으로 표준 출력됩니다.
- 성공 시: `{"success": true, "results": [...]}`
- 실패 시: `{"success": false, "error": "에러 메시지"}`
- 에이전트는 테스트 쿼리 실패 시 문법 수정 및 오류의 근본 원인을 분석하여 보고해야 합니다.
