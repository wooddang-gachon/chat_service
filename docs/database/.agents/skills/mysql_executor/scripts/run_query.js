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

const query = process.argv[2];
if (!query) {
  console.error(JSON.stringify({ success: false, error: "No SQL query provided. Usage: node run_query.js \"SELECT 1\"" }));
  process.exit(1);
}

async function main() {
  let connection;
  try {
    // DATABASE_URL 커넥션 스트링을 사용하여 MySQL 커넥션 생성
    connection = await mysql.createConnection(dbUrl);
    const [rows] = await connection.execute(query);
    console.log(JSON.stringify({ success: true, data: rows }));
  } catch (err) {
    console.error(JSON.stringify({ success: false, error: err.message }));
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

main();
