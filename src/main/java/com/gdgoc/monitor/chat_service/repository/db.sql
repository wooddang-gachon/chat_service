CREATE TABLE `user` (
`id` INT NOT NULL AUTO_INCREMENT,
`name` VARCHAR(50) NOT NULL,
`nickname` VARCHAR(50) NOT NULL,
`identify` VARCHAR(50) NOT NULL UNIQUE, -- 로그인 ID (중복 불가)
`password` VARCHAR(255) NOT NULL,       -- 암호화된 비밀번호 저장용 크기 확보
PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ChatRoom` (
`id` INT NOT NULL AUTO_INCREMENT,
`name` VARCHAR(100) NOT NULL,
`userId` INT NULL, -- 방장(개설자) ID 구조 유지
PRIMARY KEY (`id`),
CONSTRAINT `fk_ChatRoom_creator` FOREIGN KEY (`userId`) REFERENCES `user` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `userAndChatroom` (
`id` INT NOT NULL AUTO_INCREMENT,
`chatroomId` INT NOT NULL,
`userId` INT NOT NULL,
PRIMARY KEY (`id`),
UNIQUE KEY `ux_user_chatroom` (`userId`, `chatroomId`), -- 한 유저가 같은 방에 중복 참여 방지
CONSTRAINT `fk_userAndChatroom_chatroom` FOREIGN KEY (`chatroomId`) REFERENCES `ChatRoom` (`id`) ON DELETE CASCADE,
CONSTRAINT `fk_userAndChatroom_user` FOREIGN KEY (`userId`) REFERENCES `user` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `message` (
`id` INT NOT NULL AUTO_INCREMENT,
`body` TEXT NOT NULL, -- 이모지 저장을 위해 TEXT 및 utf8mb4 필수
`status` INT DEFAULT 0,
`userId` INT NOT NULL,
`chatRoom` INT NOT NULL,
`replyId` INT NULL, -- 답장 기능 (부모 메시지 ID, 상위 메시지가 없으면 NULL)
`createdAt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, -- 필수 시간 값 추가
PRIMARY KEY (`id`),
CONSTRAINT `fk_message_user` FOREIGN KEY (`userId`) REFERENCES `user` (`id`) ON DELETE NO ACTION,
CONSTRAINT `fk_message_chatroom` FOREIGN KEY (`chatRoom`) REFERENCES `ChatRoom` (`id`) ON DELETE CASCADE,
CONSTRAINT `fk_message_reply` FOREIGN KEY (`replyId`) REFERENCES `message` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `friend` (
`id` INT NOT NULL AUTO_INCREMENT,
`userId` INT NOT NULL,
`friendId` INT NOT NULL,
`accept` TINYINT(1) NOT NULL DEFAULT 0, -- MySQL의 BOOLEAN은 TINYINT(1)로 매핑됨
PRIMARY KEY (`id`),
UNIQUE KEY `ux_user_friend` (`userId`, `friendId`), -- 동일한 친구 관계 중복 생성 방지
CONSTRAINT `fk_friend_user` FOREIGN KEY (`userId`) REFERENCES `user` (`id`) ON DELETE CASCADE,
CONSTRAINT `fk_friend_target` FOREIGN KEY (`friendId`) REFERENCES `user` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;