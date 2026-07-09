채팅 서비스를 구현해보는 연습용 프로젝트

특정 주제를 처음부터 끝까지 백엔드 관점에서 기획해보는 것이 목표이다.

기본 구조는 node로 구현한 경험이 있기 때문에 이번에는 보안을 중점적으로 다룰 생각이다.

# 요구기능 정의
- 회원가입
- 로그인
- 정보 변경
- 채팅방 생성
- 채팅방 수정
- 채팅방 삭제
- 채팅 기능
- 답장 기능(status로 확인)
- 이모지 or 그림 전달 기능
- 채팅방 검색 기능
## 추가 해보면 재밌을 것 같은 기능
- excalidraw에서 web에서 링크 공유해서 서로 연동하는 기능
# DB 정의

![img.png](img.png)
```mermaid
erDiagram
    USER {
        int id PK
        varchar name
        varchar nickname
        varchar identify UK
        varchar password
    }

    CHATROOM {
        int id PK
        varchar name
        int userId FK
    }

    USERANDCHATROOM {
        int id PK
        int chatroomId FK
        int userId FK
    }

    MESSAGE {
        int id PK
        text body
        int status
        int userId FK
        int chatRoom FK
        int replyId FK
        timestamp createdAt
    }

    FRIEND {
        int id PK
        int userId FK
        int friendId FK
        boolean accept
    }

    %% 관계 정의
    USER ||--o{ CHATROOM : "creates"
    USER ||--o{ USERANDCHATROOM : "participates"
    CHATROOM ||--o{ USERANDCHATROOM : "includes"
    
    USER ||--o{ MESSAGE : "writes"
    CHATROOM ||--o{ MESSAGE : "contains"
    MESSAGE |o--o{ MESSAGE : "replies to"

    USER ||--o{ FRIEND : "requests"
    USER ||--o{ FRIEND : "receives"

```

#   API 명세

docs/api.md 참고

# 기술 스택
- springboot
- mysql
- gradle
- docker(사용하고 싶다...)