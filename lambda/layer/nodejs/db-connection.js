/**
 * Database Connection Utility
 * Mengambil credentials dari AWS Secrets Manager dan membuat koneksi MySQL
 */

const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const mysql = require('mysql2/promise');

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION || 'ap-southeast-1' });

let dbCredentials = null;
let connectionPool = null;

/**
 * Ambil database credentials dari Secrets Manager
 * Di-cache agar tidak memanggil API setiap request
 */
async function getDbCredentials() {
  if (dbCredentials) return dbCredentials;

  const command = new GetSecretValueCommand({
    SecretId: process.env.DB_SECRET_ARN,
  });

  const response = await secretsClient.send(command);
  dbCredentials = JSON.parse(response.SecretString);
  return dbCredentials;
}

/**
 * Mendapatkan connection pool ke database
 * Pool di-cache untuk reuse antar Lambda invocations (warm start)
 */
async function getConnection() {
  if (connectionPool) {
    try {
      // Test apakah koneksi masih hidup
      await connectionPool.query('SELECT 1');
      return connectionPool;
    } catch (err) {
      // Koneksi mati, buat baru
      connectionPool = null;
    }
  }

  const creds = await getDbCredentials();

  connectionPool = await mysql.createPool({
    host: creds.host,
    port: creds.port || 3306,
    user: creds.username,
    password: creds.password,
    database: creds.dbname,
    connectionLimit: 5,        // Batasi koneksi untuk Lambda
    waitForConnections: true,
    queueLimit: 0,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0,
    connectTimeout: 10000,
    acquireTimeout: 10000,
  });

  return connectionPool;
}

/**
 * Jalankan query dengan error handling
 * @param {string} sql - SQL query
 * @param {array} params - Parameter query
 * @returns {Promise<any>} Hasil query
 */
async function query(sql, params = []) {
  const pool = await getConnection();
  const [rows] = await pool.execute(sql, params);
  return rows;
}

/**
 * Jalankan transaction
 * @param {Function} callback - Function yang berisi operasi DB
 */
async function transaction(callback) {
  const pool = await getConnection();
  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();
    const result = await callback(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = { getConnection, query, transaction };
