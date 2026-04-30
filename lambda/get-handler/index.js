/**
 * Lambda GET Handler
 * Menangani semua request yang membaca data: GET
 *
 * Fitur:
 * - Semua request dan response di-log ke DynamoDB
 * - Pagination support
 * - Query filtering
 * - Error handling lengkap
 */

const { log, logApiRequest } = require('/opt/nodejs/dynamodb-logger');
const { query } = require('/opt/nodejs/db-connection');
const { success, error, cors } = require('/opt/nodejs/response-helper');

const SERVICE_ID = `lambda-get-${process.env.AWS_REGION || 'ap-southeast-1'}`;

/**
 * Main handler
 */
exports.handler = async (event) => {
  const startTime = Date.now();
  const requestId = event.requestContext?.requestId || `req-${Date.now()}`;
  const httpMethod = event.httpMethod || 'UNKNOWN';
  const path = event.path || '/';
  const sourceIp = event.requestContext?.identity?.sourceIp || 'unknown';
  const userAgent = event.headers?.['User-Agent'] || 'unknown';

  // Log request masuk
  await log(SERVICE_ID, 'INFO', `Request diterima: ${httpMethod} ${path}`, {
    requestId,
    sourceIp,
    userAgent,
    pathParameters: event.pathParameters,
    queryStringParameters: event.queryStringParameters,
  }, requestId);

  try {
    // Handle CORS preflight
    if (httpMethod === 'OPTIONS') {
      return cors();
    }

    let result;
    const pathParameters = event.pathParameters || {};
    const queryParams = event.queryStringParameters || {};

    // Routing berdasarkan path
    if (httpMethod === 'GET' && path === '/items') {
      result = await handleListItems(queryParams, requestId);
    } else if (httpMethod === 'GET' && path.match(/\/items\/[^/]+$/)) {
      result = await handleGetItemById(pathParameters.id, requestId);
    } else if (httpMethod === 'GET' && path === '/health') {
      result = await handleHealthCheck(requestId);
    } else {
      result = error('Endpoint tidak ditemukan', 404);
    }

    // Log response
    const duration = Date.now() - startTime;
    await logApiRequest({
      requestId,
      endpoint: path,
      httpMethod,
      statusCode: result.statusCode,
      durationMs: duration,
      ipAddress: sourceIp,
      userAgent,
    });

    await log(SERVICE_ID, 'INFO', `Request selesai: ${httpMethod} ${path} - ${result.statusCode}`, {
      requestId,
      durationMs: duration,
      statusCode: result.statusCode,
    }, requestId);

    return result;

  } catch (err) {
    const duration = Date.now() - startTime;

    await log(SERVICE_ID, 'ERROR', `Error pada ${httpMethod} ${path}: ${err.message}`, {
      requestId,
      errorName: err.name,
      errorStack: err.stack,
      durationMs: duration,
    }, requestId);

    await logApiRequest({
      requestId,
      endpoint: path,
      httpMethod,
      statusCode: 500,
      durationMs: duration,
      ipAddress: sourceIp,
      userAgent,
      errorMessage: err.message,
    });

    return error('Terjadi kesalahan internal server', 500, {
      errorId: requestId,
      message: err.message,
    });
  }
};

/**
 * Handler: List semua items dengan pagination
 */
async function handleListItems(queryParams, requestId) {
  const limit = Math.min(parseInt(queryParams.limit || '10'), 100); // Max 100 items
  const offset = parseInt(queryParams.offset || '0');
  const search = queryParams.search || '';

  let sql = 'SELECT * FROM items';
  let countSql = 'SELECT COUNT(*) as total FROM items';
  const params = [];
  const countParams = [];

  // Filter pencarian
  if (search) {
    sql += ' WHERE name LIKE ? OR description LIKE ?';
    countSql += ' WHERE name LIKE ? OR description LIKE ?';
    params.push(`%${search}%`, `%${search}%`);
    countParams.push(`%${search}%`, `%${search}%`);
  }

  sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const [items, countResult] = await Promise.all([
    query(sql, params),
    query(countSql, countParams),
  ]);

  const total = countResult[0].total;

  await log(SERVICE_ID, 'INFO', `List items: ${items.length} dari ${total} total`, {
    requestId,
    limit,
    offset,
    search,
    resultCount: items.length,
    totalCount: total,
  }, requestId);

  return success({
    items,
    pagination: {
      total,
      limit,
      offset,
      has_more: offset + limit < total,
      next_offset: offset + limit < total ? offset + limit : null,
    },
  });
}

/**
 * Handler: Ambil item berdasarkan ID
 */
async function handleGetItemById(itemId, requestId) {
  if (!itemId) {
    return error('ID item wajib diisi', 400);
  }

  const items = await query('SELECT * FROM items WHERE id = ?', [itemId]);

  if (items.length === 0) {
    await log(SERVICE_ID, 'WARN', `Item ID ${itemId} tidak ditemukan`, { requestId }, requestId);
    return error(`Item dengan ID ${itemId} tidak ditemukan`, 404);
  }

  await log(SERVICE_ID, 'INFO', `Item ID ${itemId} berhasil diambil`, {
    requestId,
    itemId,
    itemName: items[0].name,
  }, requestId);

  return success(items[0]);
}

/**
 * Handler: Health check & Auto-Initialization
 */
async function handleHealthCheck(requestId) {
  let dbStatus = 'healthy';
  let dbError = null;
  let initStatus = 'skipped';

  try {
    // 1. Test koneksi database
    await query('SELECT 1');
    
    // 2. Auto-initialize table if not exists (Safety mechanism)
    await query(`
      CREATE TABLE IF NOT EXISTS items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);
    initStatus = 'success';
  } catch (err) {
    dbStatus = 'unhealthy';
    dbError = err.message;
    initStatus = 'failed';
  }

  const healthData = {
    status: dbStatus === 'healthy' ? 'healthy' : 'degraded',
    service: 'lambda-get',
    timestamp: new Date().toISOString(),
    database_init: initStatus,
    checks: {
      database: {
        status: dbStatus,
        error: dbError,
      },
      environment: process.env.NODE_ENV,
      region: process.env.AWS_REGION,
    },
  };

  const statusCode = dbStatus === 'healthy' ? 200 : 503;

  await log(SERVICE_ID, dbStatus === 'healthy' ? 'INFO' : 'WARN',
    `Health check: ${healthData.status}`, healthData, requestId);

  return success(healthData, statusCode, `Service ${healthData.status}`);
}
