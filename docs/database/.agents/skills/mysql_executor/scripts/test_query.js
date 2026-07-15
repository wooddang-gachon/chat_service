import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 프로젝트 루트의 .env 파일 탐색 및 로드
dotenv.config({ path: path.resolve(__dirname, '../../../../.env') });

const dbUrl = process.env.DATABASE_URL;

if (!dbUrl) {
  console.error(JSON.stringify({ success: false, error: "DATABASE_URL is not defined in .env file." }));
  process.exit(1);
}

const rawQueries = process.argv[2];
if (!rawQueries) {
  console.error(JSON.stringify({ success: false, error: "No SQL queries provided. Usage: node test_query.js \"INSERT INTO ...; SELECT ...;\"" }));
  process.exit(1);
}

// 세미콜론(;) 기준으로 쿼리를 분할하여 실행 배열 생성
const queries = rawQueries.split(';').map(q => q.trim()).filter(q => q.length > 0);

async function main() {
  let connection;
  const results = [];
  try {
    connection = await mysql.createConnection(dbUrl);
    
    // 1. 트랜잭션 시작 (Autocommit 비활성화)
    await connection.beginTransaction();
    
    // 2. 분할된 쿼리를 순차적으로 실행
    for (const sql of queries) {
      const [rows] = await connection.execute(sql);
      results.push({ query: sql, success: true, data: rows });
    }
    
    // 3. 테스트 성공 결과 출력 (JSON 형태)
    console.log(JSON.stringify({ success: true, results }));
  } catch (err) {
    // 쿼리 중 실패 발생 시 시점까지 실행된 내역과 함께 에러 출력
    console.error(JSON.stringify({ success: false, error: err.message, executed: results }));
  } finally {
    if (connection) {
      try {
        // 4. 어떤 경우든 무조건 롤백(Rollback)을 수행하여 DB의 물리적 데이터를 복구
        await connection.rollback();
      } catch (rollbackErr) {
        console.error(JSON.stringify({ success: false, error: "Rollback failed: " + rollbackErr.message }));
      }
      await connection.end();
    }
  }
}

main();
