# Chat Service API Specification

이 문서는 채팅 서비스의 REST API 명세서입니다. 데이터베이스 스키마(user, ChatRoom, userAndChatroom, message, friend)를 바탕으로 설계되었습니다.

---

## 공통 요청 헤더 (Common Request Headers)

인증이 필요한 모든 API 요청은 아래의 헤더를 포함해야 합니다.

| Key               | Value                | Description                          |
|:------------------|:---------------------|:-------------------------------------|
| **Content-Type**  | `application/json`   | API 요청 데이터 포맷 (필수)                   |
| **Authorization** | `Bearer <JWT_TOKEN>` | 로그인 성공 시 발급받은 JWT 토큰 (인증 필수 API의 경우) |

---

## 1. Authentication & User API (인증 및 유저 API)

### 1.1 회원가입 (Sign Up)
- **Endpoint**: `POST /api/users/signup`
- **Description**: 새로운 사용자를 등록합니다.
- **Headers**:
  - `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "identify": "user_id_example",
    "password": "securePassword123!",
    "name": "홍길동",
    "nickname": "길동이"
  }
  ```
- **Response**:
  - `201 Created`
  ```json
  {
    "id": 1,
    "identify": "user_id_example",
    "name": "홍길동",
    "nickname": "길동이"
  }
  ```

### 1.2 로그인 (Sign In)
- **Endpoint**: `POST /api/users/signin`
- **Description**: 사용자 로그인을 처리하고 JWT 토큰 혹은 세션을 반환합니다.
- **Headers**:
  - `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "identify": "user_id_example",
    "password": "securePassword123!"
  }
  ```
- **Response**:
  - `200 OK`
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "identify": "user_id_example",
      "nickname": "길동이"
    }
  }
  ```

---

## 2. Friend API (친구 관리 API)

### 2.1 친구 요청 전송 (Send Friend Request)
- **Endpoint**: `POST /api/friends/request`
- **Description**: 특정 사용자에게 친구 요청을 보냅니다.
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Request Body**:
  ```json
  {
    "friendId": 2
  }
  ```
- **Response**:
  - `200 OK`
  ```json
  {
    "id": 5,
    "userId": 1,
    "friendId": 2,
    "accept": false
  }
  ```

### 2.2 친구 요청 수락 (Accept Friend Request)
- **Endpoint**: `PUT /api/friends/accept/{requestId}`
- **Description**: 받은 친구 요청을 수락합니다.
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Response**:
  - `200 OK`
  ```json
  {
    "id": 5,
    "userId": 1,
    "friendId": 2,
    "accept": true
  }
  ```

### 2.3 친구 목록 조회 (Get Friend List)
- **Endpoint**: `GET /api/friends`
- **Description**: 수락된 친구 목록을 조회합니다.
- **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Response**:
  - `200 OK`
  ```json
  [
    {
      "id": 2,
      "name": "이순신",
      "nickname": "거북선"
    }
  ]
  ```

---

## 3. ChatRoom API (채팅방 API)

### 3.1 채팅방 생성 (Create Chat Room)
- **Endpoint**: `POST /api/chatrooms`
- **Description**: 새로운 채팅방을 개설합니다.
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Request Body**:
  ```json
  {
    "name": "GDGOC 백엔드 스터디방"
  }
  ```
- **Response**:
  - `201 Created`
  ```json
  {
    "id": 10,
    "name": "GDGOC 백엔드 스터디방",
    "userId": 1
  }
  ```

### 3.2 채팅방 참여 (Join Chat Room)
- **Endpoint**: `POST /api/chatrooms/{chatroomId}/join`
- **Description**: 특정 채팅방에 참여(입장)합니다.
- **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Response**:
  - `200 OK`
  ```json
  {
    "id": 20,
    "chatroomId": 10,
    "userId": 1
  }
  ```

### 3.3 내 채팅방 목록 조회 (Get Joined Chat Rooms)
- **Endpoint**: `GET /api/chatrooms`
- **Description**: 내가 참여하고 있는 채팅방 목록을 가져옵니다.
- **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Response**:
  - `200 OK`
  ```json
  [
    {
      "id": 10,
      "name": "GDGOC 백엔드 스터디방",
      "creatorId": 1
    }
  ]
  ```

---

## 4. Message API (메시지 API)

### 4.1 메시지 전송 (Send Message)
- **Endpoint**: `POST /api/chatrooms/{chatroomId}/messages`
- **Description**: 특정 채팅방에 메시지를 보냅니다. 답장 기능 사용 시 `replyId`를 전달합니다.
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Request Body**:
  ```json
  {
    "body": "안녕하세요! 오늘 스터디 몇 시인가요?",
    "replyId": null
  }
  ```
- **Response**:
  - `201 Created`
  ```json
  {
    "id": 100,
    "body": "안녕하세요! 오늘 스터디 몇 시인가요?",
    "status": 0,
    "userId": 1,
    "chatRoom": 10,
    "replyId": null,
    "createdAt": "2026-07-08T14:18:11Z"
  }
  ```

### 4.2 채팅방 메시지 내역 조회 (Get Messages)
- **Endpoint**: `GET /api/chatrooms/{chatroomId}/messages`
- **Description**: 특정 채팅방의 이전 메시지 내역을 커서 기반(No-offset) 페이징 기법으로 조회합니다. 실시간으로 메시지가 추가되는 채팅 특성상 오프셋 기반 페이징 시 데이터 누락/중복이 발생할 수 있어 마지막 조회한 메시지 ID를 기준으로 페이징을 처리합니다.
- **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>` (필수)
- **Query Parameters**:

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `lastMessageId` | Integer | No | 이전에 조회한 메시지 중 가장 마지막(가장 오래된/가장 최근의) 메시지 ID. 첫 페이지 요청 시에는 포함하지 않습니다. |
| `size` | Integer | No | 한 번에 조회할 메시지 개수 (기본값: 20) |
- **Response**:
  - `200 OK`
  ```json
  [
    {
      "id": 99,
      "body": "이전 메시지 내용입니다.",
      "status": 0,
      "userId": 2,
      "chatRoom": 10,
      "replyId": null,
      "createdAt": "2026-07-08T14:15:00Z"
    },
    {
      "id": 98,
      "body": "그 전 메시지 내용입니다.",
      "status": 0,
      "userId": 1,
      "chatRoom": 10,
      "replyId": null,
      "createdAt": "2026-07-08T14:12:00Z"
    }
  ]
  ```

